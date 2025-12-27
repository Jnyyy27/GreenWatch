# TensorFlow Lite Model Setup Guide

## Downloads Required

### 1. MobileNetV2 TFLite Model (14.5 MB)
Download from: https://www.tensorflow.org/lite/guide/hosted_models

**Direct Link:** https://storage.googleapis.com/download.tensorflow.org/models/mobilenet_v2_1.0_224.tflite

**Save to:** `assets/models/mobilenet_v2_1.0_224.tflite`

### 2. ImageNet Labels (35 KB)
Download from: https://raw.githubusercontent.com/tensorflow/tensorflow/master/tensorflow/lite/java/demo/src/main/assets/labels_imagenet_slim.txt

**Direct Link:** https://storage.googleapis.com/download.tensorflow.org/data/imagenet_slim_labels.txt

**Save to:** `assets/models/imagenet_labels.txt`

## Quick Setup Instructions

### Option A: Manual Download (Recommended)
1. Download both files from the links above
2. Create `assets/models/` folder in your project root
3. Place both files in that folder
4. Run `flutter pub get`

### Option B: Using curl (Windows PowerShell)
```powershell
# Create directory
New-Item -ItemType Directory -Path "assets/models" -Force

# Download model
Invoke-WebRequest -Uri "https://storage.googleapis.com/download.tensorflow.org/models/mobilenet_v2_1.0_224.tflite" -OutFile "assets/models/mobilenet_v2_1.0_224.tflite"

# Download labels
Invoke-WebRequest -Uri "https://storage.googleapis.com/download.tensorflow.org/data/imagenet_slim_labels.txt" -OutFile "assets/models/imagenet_labels.txt"
```

### Option C: Using curl (Linux/Mac)
```bash
mkdir -p assets/models

curl -o assets/models/mobilenet_v2_1.0_224.tflite \
  https://storage.googleapis.com/download.tensorflow.org/models/mobilenet_v2_1.0_224.tflite

curl -o assets/models/imagenet_labels.txt \
  https://storage.googleapis.com/download.tensorflow.org/data/imagenet_slim_labels.txt
```

## Verification

After downloading, verify the files:
- `mobilenet_v2_1.0_224.tflite` should be ~14.5 MB
- `imagenet_labels.txt` should be ~35 KB

## What These Models Do

### MobileNetV2 (224x224)
- Pre-trained on ImageNet dataset (1000 object classes)
- Lightweight and fast (runs in ~50-100ms on mobile)
- Perfect for on-device inference
- Optimized for mobile/edge devices

### ImageNet Labels
- Human-readable labels for the 1000 classes
- Includes environmental categories like:
  - pollution, trash, garbage, waste
  - water, river, lake, ocean
  - factory, industrial, smoke, fire
  - and 1000 more classes

## Integration with Report Validation

The `MLValidatorService` uses these models to:

1. **Classify the uploaded image** - Determines what's in the image
2. **Check relevance** - Verifies it's related to environmental issues
3. **Validate quality** - Checks image size and clarity
4. **Detect duplicates** - Compares with previous submissions

## Usage Example

```dart
// Initialize the service
MLValidatorService validator = MLValidatorService();
await validator.initialize();

// Validate an image
ValidationResult result = await validator.validateImage('path/to/image.jpg');

if (result.isValid) {
  print('✅ Image is valid for submission');
  print('Detected: ${result.topPrediction?.label}');
} else {
  print('❌ ${result.message}');
}

// Check for duplicates
DuplicateDetectionResult dup = await validator.checkForDuplicates(
  'new_image.jpg',
  'previous_image.jpg'
);

if (dup.isDuplicate) {
  print('⚠️ Similar image found (${dup.similarity * 100}% match)');
}
```

## Troubleshooting

### Model files not found
- Ensure files are in `assets/models/` directory
- Check `pubspec.yaml` has the asset declarations
- Run `flutter pub get` after adding files

### "Asset not found" error at runtime
- Verify file paths match exactly: `assets/models/mobilenet_v2_1.0_224.tflite`
- Ensure pubspec.yaml assets section is correct
- Try `flutter clean` and `flutter pub get`

### Slow performance
- MobileNetV2 should process images in 50-100ms
- First run may be slower due to model loading
- Consider running validation in background isolate for large batches

### Out of memory errors
- Image size should not exceed 1-2MB
- Compression in ImageValidator widget helps
- Dispose of MLValidatorService when done

## Performance Notes

- **Model size:** 14.5 MB (loaded once into memory)
- **Image processing:** 50-100ms per image on modern devices
- **Memory usage:** ~50-100 MB including model
- **Accuracy:** ~80% for general object detection

## Security & Privacy

- ✅ All processing happens on-device (no cloud upload)
- ✅ No API costs
- ✅ User data never leaves the device
- ✅ Works offline (after first model load)

## Further Customization

For more control, you can:
1. Use a custom-trained model (export from TensorFlow)
2. Adjust confidence thresholds in `MLValidatorService`
3. Add more environmental keywords to `ENVIRONMENTAL_KEYWORDS`
4. Implement your own duplicate detection algorithm

## References

- TensorFlow Lite: https://www.tensorflow.org/lite
- MobileNetV2: https://arxiv.org/abs/1801.04381
- ImageNet: http://www.image-net.org/
