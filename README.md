# Gotcha

[![Swift](https://img.shields.io/badge/Swift-5.0-F05138?logo=swift&logoColor=white)](https://www.swift.org/) [![SwiftUI](https://img.shields.io/badge/SwiftUI-UIKit%20free-06B6D4?logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftui/) [![iOS](https://img.shields.io/badge/iOS-18.0%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/ios/) [![ActivityKit](https://img.shields.io/badge/Dynamic%20Island-Live%20Activity-5E5CE6)](https://developer.apple.com/documentation/activitykit)

<a href="https://testflight.apple.com/join/nvfjcUC5"><img src="https://img.shields.io/badge/Download_on_TestFlight-0D96F6?style=for-the-badge&logo=apple&logoColor=white" alt="Download on TestFlight"></a>

## Project

Gotcha is an audio recorder for iPhone. It continuously keeps the last 1 to 3 minutes of microphone audio in a rolling loop, so you can save a clip of something after it already happened.

## Problem Statement

People who want to capture audio are often blocked by one of these constraints:

1. Recording apps only capture what happens after you press record, so it's useless for anything like this unless you want to burn your SSD.
2. Pulling out your phone, unlocking it, and starting a recording makes people suspicious.
3. A raw audio file is hard to use when there is no easy editing options.

## How Gotcha Solves It

Gotcha has:

1. A rolling loop that continuously holds the last *x* minutes of audio, discarding anything uncaptured automatically.
2. One tap to capture from the app, the Dynamic Island, or the Lock Screen.
3. A clip editor with trimming, subtitles, waveforms, and export.

## Who It Is For

Gotcha is designed for:

Anyone who wants to clip audio after it happened.