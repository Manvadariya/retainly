# YouTube Service Implementation Deployment Guide

Follow these steps to replace the old YouTubeService with the new implementation.

## 1. Update Dependencies

Ensure the required packages are in your pubspec.yaml:

```yaml
dependencies:
  http: ^1.2.2
  html: ^0.15.4
  xml: ^6.3.0
```

Run the following command to install dependencies:

```
flutter pub get
```

## 2. Replace Files

1. Rename the new files by replacing the existing implementations:

```
youtube_service.dart.new → youtube_service.dart
add_card_bloc.dart.new → add_card_bloc.dart
```

2. Delete the temporary files (if any):
   - `new_youtube_service.dart` 
   - `youtube_service_exports.dart`

## 3. Database Migration

The schema changes will automatically apply when the app is launched and the database is opened, thanks to the migration we've added in the `AppDatabase` class.

## 4. Testing

After deployment, test the following:

1. Adding YouTube links of different formats:
   - Regular watch URLs: `https://www.youtube.com/watch?v=VIDEO_ID`
   - Short URLs: `https://youtu.be/VIDEO_ID`
   - Shorts: `https://www.youtube.com/shorts/VIDEO_ID`

2. Verify that metadata is properly displayed:
   - Title
   - Thumbnail
   - Transcript (if available)

3. Check that the loading states are properly shown

## 5. Rollback Plan (If Needed)

If issues are encountered:

1. Restore the previous `youtube_service.dart` file
2. Restore the previous `add_card_bloc.dart` file
3. Temporarily disable the metadata column usage in the card repository by modifying the `mapRowToCardEntity` method

## Implementation Notes

The new implementation provides:

1. Better structured metadata extraction
2. More reliable transcript fetching with multiple fallbacks
3. Loading indicators for improved user experience
4. Complete offline caching of thumbnails and metadata
5. Enhanced error handling and logging

The metadata is stored in the database as a JSON string, which allows for future expansion without requiring database schema changes.