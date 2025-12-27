# Duplicate Detection Logic - Complete Overview

## Hard Duplicate Rule (Immediate Duplicate)
Applied BEFORE composite scoring. If **ALL** conditions met, immediately marks as duplicate:
- ✅ **Same Category** (enforced by Firestore query filter)
- ✅ **Same Day** (calendar day match, checked with `_isSameDayOrToday()`)
- ✅ **Within 100 meters** (distance in meters <= 100.0)
- ✅ **High Description Similarity** (> 0.7 using Jaccard token overlap)

**Result:** Returns `isDuplicate: true` with score 1.0 immediately, bypassing composite threshold.

---

## Composite Scoring (Fallback)
If hard rule doesn't trigger, calculates weighted composite score:

### Location Score (0–1)
Based on distance between coordinates (Haversine formula):
```
Distance <= 30m  → 1.0 (same location)
Distance <= 50m  → 0.8 (very close)
Distance <= 100m → 0.5 (close)
Distance > 100m  → 0.0 (too far)
```

### Timeline Score (0–1)
Based on report age (calendar day comparison):
```
Same day (daysDifference = 0)  → 1.0
Within 3 days                  → 0.8
Within 7 days                  → 0.4
Older than 7 days              → 0.0
```

### Description Score (0–1)
Jaccard similarity on tokenized descriptions:
```
Score = |intersection| / |union|  (0.0 = no match, 1.0 = identical)
```

### Image Similarity Score (0–1)
Cosine similarity on embeddings:
```
Score = dot(embedding1, embedding2) / (||embedding1|| * ||embedding2||)
Clamped to [0.0, 1.0]
```

### Category Score
Always 1.0 (enforced by Firestore category filter)

---

## Composite Score Calculation
**Weights (sum = 100%):**
- Category: 15%
- Location: 10%
- Description: 35% ← highest weight (most important)
- Image: 20%
- Timeline: 20%

**Formula:**
```
compositeScore = 
  (categoryScore * 0.15) +
  (locationScore * 0.10) +
  (descriptionScore * 0.35) +
  (imageSimilarity * 0.20) +
  (timelineScore * 0.20)
```

**Result:** If `compositeScore >= similarityThreshold` (default 0.75), mark as duplicate.

---

## Verification Status Filter
**Only compares against successfully verified reports:**
```
verificationStatus == 'Submitted' ||
status == 'successfully verified' ||
autoVerified == true
```

This ensures pending/unsuccessful reports don't interfere with duplicate detection.

---

## Debug Logging
### Hard Rule Triggers
Logs: `🚨 HARD DUPLICATE RULE TRIGGERED: Report {id} (same day, {distance}m away, description similarity {score}%)`

### Composite Scoring
Logs per-comparison breakdown:
```
📊 Report {id} - Category: X%, Location: Y%, Description: Z%, Image: A%, Timeline: B% → Total: C%
```

### Near-Miss Logging (Firestore)
Saves comparisons with score >= (threshold - 0.15) to `duplicateDebug` field:
```json
{
  "duplicateDebug": {
    "nearMisses": [
      {
        "comparedReportId": "xxx",
        "compositeScore": 0.72,
        "categoryScore": 1.0,
        "locationScore": 0.5,
        "descriptionScore": 0.8,
        "imageSimilarity": 0.6,
        "timelineScore": 0.8,
        "reportLatitude": 37.123,
        "reportLongitude": -122.456,
        "createdAt": <timestamp>
      }
    ],
    "checkedAt": <timestamp>
  }
}
```

---

## Example Scenarios

### Scenario 1: Hard Rule Triggers
- Same category: ✓ Road potholes
- Same day: ✓ (both submitted today)
- Distance: ✓ 50 meters away
- Description: ✓ "Large pothole" vs "Large hole" → 0.75 similarity
- **Result:** Immediately marked as DUPLICATE (hard rule), no composite check

### Scenario 2: Different Issues, Same Location
- Category: ✓ Both "Road potholes"
- Same day: ✓
- Distance: ✓ 5 meters away
- Description: ✗ "Pothole on Main St" vs "Broken streetlight on Main St" → 0.2 similarity
- Composite: 0.15 + 0.10 + (0.2*0.35) + 0.20 + 0.20 ≈ 0.57
- **Result:** NOT DUPLICATE (below 0.75 threshold)

### Scenario 3: High Similarity, Different Day
- Category: ✓ Same
- Same day: ✗ (3 days old)
- Distance: ✓ 10 meters
- Description: ✓ High similarity (0.85)
- Image: ✓ 0.80 similarity
- Timeline: 0.8 (within 3 days)
- Composite: (0.15) + (1.0*0.10) + (0.85*0.35) + (0.80*0.20) + (0.8*0.20) ≈ 0.70
- **Result:** NOT DUPLICATE (below 0.75, hard rule didn't trigger)

---

## Configuration Parameters
To tune duplicate detection, adjust these in `_checkDuplicatesWithScoring()`:

```dart
// Hard rule thresholds
const double HARD_RULE_DISTANCE_M = 100.0;      // ← adjust distance
const double HARD_RULE_DESC_SIMILARITY = 0.7;   // ← adjust description threshold

// Composite threshold
double similarityThreshold = 0.75;  // ← adjust overall threshold

// Weights (adjust in composite score calculation)
// e.g., increase description weight if you want stricter text matching
```

---

## Summary
- **Hard Rule:** Fast-fail for obvious duplicates (same day + close + similar description)
- **Composite Scoring:** Nuanced matching considering all 5 factors with configurable weights
- **Verified Reports Only:** Prevents unsuccessful reports from interfering
- **Logging:** Comprehensive logs and Firestore debug fields for troubleshooting
