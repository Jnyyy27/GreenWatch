# TensorFlow Lite + MobileNetV2 Implementation Guide

## Overview

You now have a complete AI-powered image validation system for your GreenWatch app! This guide explains how to integrate it into your existing report submission flow, including sensitive content detection and smart duplicate detection.

## ✅ What's Included

### 1. **ML Validator Service** (`lib/services/ml_validator_service.dart`)
The core ML engine that:
- **Classifies images** using MobileNetV2 pre-trained model
- **Validates environmental relevance** - checks if image is related to environmental issues
- **Detects duplicates** - smart hard-rule + composite scoring system
- **Checks image quality** - validates minimum size, clarity, etc.
- **Extracts embeddings** - for future duplicate detection

### 2. **Report Service** (`lib/services/report_service.dart`)
Backend processing:
- **Sensitive content validation** - checks description for harmful words
- **Duplicate scoring** - calculates comprehensive similarity across 5 factors
- **Verification metadata** - stores ML results in Firestore
- **Debug logging** - near-miss comparisons for troubleshooting

### 3. **Report Screen** (`lib/app_mobile/screens/report_screen.dart`)
Frontend integration:
- **Sensitive words detection** - warns/blocks harmful content
- **Image validation** - ML classification before submission
- **Duplicate warnings** - alerts user if similar reports found
- **UX helpers** - smooth dialogs and snackbars

### 4. **Setup Guide** (`TENSORFLOWLITE_SETUP.md`)
Instructions for downloading required ML models

## 🚀 Quick Start (3 Steps)

### Step 1: Download ML Models
```powershell
# Run in project root (PowerShell)
New-Item -ItemType Directory -Path "assets/models" -Force

Invoke-WebRequest -Uri "https://storage.googleapis.com/download.tensorflow.org/models/mobilenet_v2_1.0_224.tflite" -OutFile "assets/models/mobilenet_v2_1.0_224.tflite"

Invoke-WebRequest -Uri "https://storage.googleapis.com/download.tensorflow.org/data/imagenet_slim_labels.txt" -OutFile "assets/models/imagenet_labels.txt"
```

### Step 2: Update Dependencies
Already done! Your `pubspec.yaml` now includes:
- `tflite_flutter: ^0.10.4` - TensorFlow Lite binding
- `tflite_flutter_helper: ^0.0.1` - Helper utilities

Run:
```bash
flutter pub get
```

### Step 3: Integrate into Your Report Screen

**Already integrated!** The report flow now includes:

#### 1. Sensitive Content Validation
Checked before submission in `_submitReport()`:
```dart
final descMatches = _findSensitiveWords(_descriptionController.text);
if (descMatches.isNotEmpty) {
  // Show warning and submit anyway (marked unsuccessful)
  _showSnackBar('Description contains sensitive words. Report will be marked unsuccessful.');
}
```

#### 2. Image Classification
MobileNetV2 validates that image matches the reported category:
```dart
final validationResult = await _mlValidator.validateImage(
  imagePath,
  category: _selectedCategory,
  description: _descriptionController.text,
);
```

#### 3. Duplicate Detection
Smart duplicate checking with hard-rule + composite scoring:
```dart
// Hard Rule: Same day + 100m + 0.7+ description match = INSTANT DUPLICATE
// Composite Score: 5-factor weighted average (location, description, image, timeline, category)
final dupResult = await _mlValidator.checkForDuplicates(
  imagePath: imagePath,
  category: category,
  latitude: latitude,
  longitude: longitude,
  similarityThreshold: 0.75,
);
```

#### 4. Verification & Storage
Results automatically stored in Firestore:
```dart
{
  "verificationStatus": "submitted",  // or "unsuccessful" if flagged
  "isDuplicate": false,
  "duplicateScore": 0.45,
  "embedding": [0.123, 0.456, ...],  // For future comparisons
  "duplicateDebug": {                // Near-miss logging for troubleshooting
    "nearMisses": [...]
  }
}
```

## 📋 Key Features

### Sensitive Content Validation
- **Detects:** violence, bomb, kill, murder, terror, suicide, sex, porn, drug, attack, racist, slur
- **Action:** Marks report unsuccessful automatically
- **Customizable:** Edit `_sensitiveWords` set in `report_screen.dart`
- **Result:** Report submitted but hidden until admin review

### Hard Duplicate Rule
Triggers immediately if ALL conditions met (before composite scoring):
- ✅ Same category
- ✅ Same calendar day
- ✅ Within 100 meters
- ✅ Description similarity > 70% (Jaccard token overlap)

**Result:** `isDuplicate: true`, score 1.0, rejection message

### Composite Duplicate Scoring
If hard rule doesn't trigger, calculates weighted score:

| Factor | Weight | Logic |
|--------|--------|-------|
| **Location** | 10% | 30m=1.0, 50m=0.8, 100m=0.5, 100m+=0.0 |
| **Description** | 35% | Jaccard similarity (token overlap) |
| **Image** | 20% | Cosine similarity on embeddings |
| **Timeline** | 20% | Same day=1.0, 3 days=0.8, 7 days=0.4, 7+=0.0 |
| **Category** | 15% | Always 1.0 (pre-filtered) |

**Threshold:** 0.75 (75% similarity)
**Result:** If score >= threshold, mark as duplicate

### Verified Reports Only
Only compares against successfully verified reports:
```dart
verificationStatus == 'Submitted' ||
status == 'successfully verified' ||
autoVerified == true
```

This prevents pending/unsuccessful reports from false-positive matches.

### Debug Logging
Near-miss comparisons saved to Firestore for troubleshooting:
```json
{
  "duplicateDebug": {
    "nearMisses": [
      {
        "comparedReportId": "abc123",
        "compositeScore": 0.72,
        "locationScore": 0.5,
        "descriptionScore": 0.8,
        "imageSimilarity": 0.6,
        "timelineScore": 0.8
      }
    ],
    "checkedAt": <timestamp>
  }
}
```

## 🔧 Configuration

To adjust duplicate detection, edit `report_service.dart`:

```dart
// In _checkDuplicatesWithScoring():

// Hard rule parameters
const double HARD_RULE_DISTANCE_M = 100.0;      // Distance threshold
const double HARD_RULE_DESC_SIMILARITY = 0.7;   // Description match threshold

// Composite scoring weights (must sum to 1.0)
final double compositeScore =
  (categoryScore * 0.15) +      // 15%
  (locationScore * 0.10) +      // 10%
  (descriptionScore * 0.35) +   // 35% ← increase for stricter matching
  (imageSimilarity * 0.20) +    // 20%
  (timelineScore * 0.20);       // 20%

// Composite threshold (0-1)
double similarityThreshold = 0.75;  // 75% match required
```

## 📚 Complete Documentation

For detailed information, see:
- `DUPLICATE_DETECTION_LOGIC.md` - Complete flow diagrams and examples
- `README_ML_VALIDATION.md` - Feature overview and FAQ
- `TENSORFLOWLITE_SETUP.md` - Model download instructions

## ✅ Validation Checklist

- [x] Sensitive content validation
- [x] Image classification (MobileNetV2)
- [x] Environmental relevance checking
- [x] Hard duplicate rule
- [x] Composite duplicate scoring
- [x] Image embedding extraction
- [x] Firestore verification storage
- [x] Debug logging
- [x] Near-miss tracking