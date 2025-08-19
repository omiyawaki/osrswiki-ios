//
//  osrsSpeechRecognitionManager.swift
//  osrswiki
//
//  Created on voice search implementation session
//

import Foundation
import Speech
import AVFoundation
import SwiftUI

@MainActor
class osrsSpeechRecognitionManager: NSObject, ObservableObject {
    
    enum SpeechState {
        case idle
        case listening
        case processing
        case error
    }
    
    @Published var currentState: SpeechState = .idle
    @Published var isListening = false
    @Published var errorMessage: String?
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private var onResult: ((String) -> Void)?
    private var onPartialResult: ((String) -> Void)?
    private var onError: ((String) -> Void)?
    private var onStateChanged: ((SpeechState) -> Void)?
    
    private var lastClickTime: TimeInterval = 0
    private let debounceInterval: TimeInterval = 1.0
    
    override init() {
        super.init()
        setupSpeechRecognizer()
    }
    
    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
        speechRecognizer?.delegate = self
    }
    
    func configure(
        onResult: @escaping (String) -> Void,
        onPartialResult: @escaping (String) -> Void = { _ in },
        onError: @escaping (String) -> Void,
        onStateChanged: @escaping (SpeechState) -> Void = { _ in }
    ) {
        self.onResult = onResult
        self.onPartialResult = onPartialResult
        self.onError = onError
        self.onStateChanged = onStateChanged
    }
    
    func startVoiceRecognition() {
        print("osrsSpeechRecognitionManager: startVoiceRecognition() called, current state: \(currentState)")
        
        // Debounce rapid clicks
        let currentTime = Date().timeIntervalSince1970
        if currentTime - lastClickTime < debounceInterval {
            print("osrsSpeechRecognitionManager: Ignoring rapid click (debounced)")
            return
        }
        lastClickTime = currentTime
        
        // Handle different states
        switch currentState {
        case .listening:
            print("osrsSpeechRecognitionManager: Currently listening, stopping recognition")
            stopListening()
            return
        case .processing:
            print("osrsSpeechRecognitionManager: Already processing, ignoring request")
            return
        case .error, .idle:
            break
        }
        
        // Check if speech recognition is available
        guard let speechRecognizer = speechRecognizer else {
            updateState(.error)
            let errorMsg = "Speech recognition is not available on this device."
            self.errorMessage = errorMsg
            onError?(errorMsg)
            return
        }
        
        guard speechRecognizer.isAvailable else {
            updateState(.error)
            let errorMsg = "Speech recognition is currently not available. Please try again later."
            self.errorMessage = errorMsg
            onError?(errorMsg)
            return
        }
        
        // Request permissions and start listening
        requestPermissionsAndStartListening()
    }
    
    private func requestPermissionsAndStartListening() {
        Task {
            do {
                // Request speech recognition authorization
                let speechAuthStatus = await requestSpeechRecognitionPermission()
                guard speechAuthStatus == .authorized else {
                    let errorMsg = speechAuthStatus == .denied ? 
                        "Speech recognition permission denied. Please enable it in Settings." :
                        "Speech recognition permission not available."
                    await handleError(errorMsg)
                    return
                }
                
                // Request microphone permission
                let micAuthStatus = await requestMicrophonePermission()
                guard micAuthStatus == .granted else {
                    let errorMsg = "Microphone access denied. Please enable it in Settings to use voice search."
                    await handleError(errorMsg)
                    return
                }
                
                // Start listening
                try await startListening()
                
            } catch {
                await handleError("Failed to start voice recognition: \(error.localizedDescription)")
            }
        }
    }
    
    private func requestSpeechRecognitionPermission() async -> SFSpeechRecognizerAuthorizationStatus {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
    
    private func requestMicrophonePermission() async -> AVAudioSession.RecordPermission {
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted ? .granted : .denied)
            }
        }
    }
    
    private func startListening() async throws {
        print("osrsSpeechRecognitionManager: startListening() called")
        
        // Provide haptic feedback
        let impactGenerator = UIImpactFeedbackGenerator(style: .light)
        impactGenerator.impactOccurred()
        
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Prepare audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw NSError(domain: "SpeechRecognition", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"])
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Update state
        updateState(.listening)
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                if let result = result {
                    let transcription = result.bestTranscription.formattedString
                    print("osrsSpeechRecognitionManager: Transcription - \(transcription)")
                    
                    if result.isFinal {
                        print("osrsSpeechRecognitionManager: Final result: '\(transcription)'")
                        self?.onResult?(transcription)
                        self?.stopListening()
                    } else {
                        print("osrsSpeechRecognitionManager: Partial result: '\(transcription)'")
                        self?.onPartialResult?(transcription)
                    }
                }
                
                if let error = error {
                    print("osrsSpeechRecognitionManager: Recognition error: \(error)")
                    await self?.handleError(self?.getErrorMessage(from: error) ?? "Recognition failed")
                }
            }
        }
        
        // Start audio engine
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        print("osrsSpeechRecognitionManager: Speech recognition started successfully")
    }
    
    func stopListening() {
        print("osrsSpeechRecognitionManager: stopListening() called")
        
        // Stop audio engine
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // Clean up recognition request
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // Update state based on current state
        if currentState == .listening {
            updateState(.processing)
        }
        
        // Clean up audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("osrsSpeechRecognitionManager: Failed to deactivate audio session: \(error)")
        }
    }
    
    private func updateState(_ newState: SpeechState) {
        currentState = newState
        isListening = newState == .listening
        onStateChanged?(newState)
        
        // Clear error when state changes from error
        if newState != .error {
            errorMessage = nil
        }
        
        // Auto-reset to idle from processing after a delay
        if newState == .processing {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if self.currentState == .processing {
                    self.updateState(.idle)
                }
            }
        }
    }
    
    private func handleError(_ message: String) async {
        print("osrsSpeechRecognitionManager: Error - \(message)")
        updateState(.error)
        errorMessage = message
        onError?(message)
        
        // Clean up
        stopListening()
        
        // Auto-reset to idle after error display
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if self.currentState == .error {
                self.updateState(.idle)
            }
        }
    }
    
    private func getErrorMessage(from error: Error) -> String {
        if let nsError = error as NSError? {
            switch nsError.code {
            case 203: // No speech detected
                return "No speech detected. Please speak clearly and try again."
            case 216: // Network error
                return "Network error. Please check your internet connection and try again."
            case 301: // Audio recording error
                return "Microphone error. Please check if another app is using the microphone."
            default:
                return "Speech recognition error. Please try again."
            }
        }
        return error.localizedDescription
    }
    
    func cleanup() {
        print("osrsSpeechRecognitionManager: cleanup() called")
        
        // Stop any ongoing recognition
        if currentState == .listening || currentState == .processing {
            stopListening()
        }
        
        // Cancel recognition task
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        // Reset state
        updateState(.idle)
    }
    
    deinit {
        // Can't call cleanup() from deinit in @MainActor context
        // The system will clean up resources when the object is deallocated
    }
}

// MARK: - SFSpeechRecognizerDelegate
extension osrsSpeechRecognitionManager: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        print("osrsSpeechRecognitionManager: Speech recognizer availability changed to: \(available)")
        
        Task { @MainActor in
            if !available && (self.currentState == .listening || self.currentState == .processing) {
                await self.handleError("Speech recognition became unavailable. Please try again later.")
            }
        }
    }
}