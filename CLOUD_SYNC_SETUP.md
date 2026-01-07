# Hybrid Athlete Cloud Sync Configuration

## Current Cloud Sync Destination

### Primary Service (Recommended)
**Service**: Your personal cloud storage
**URL**: `https://api.hybrid-athlete.com` (placeholder - you need to set this up)
**Features**: 
- Private data storage
- Fast sync speeds
- Full control over data
- Custom configuration

### Fallback Service (Temporary)
**Service**: jsonbin.org (free service)
**URL**: `https://jsonbin.org/hybrid-athlete`
**Features**:
- Free to use
- Limited storage
- Public access (not secure)
- For testing only

## Recommended Setup Options

### Option 1: Your Own Cloud Server
```bash
# Setup your own API server
- Node.js/Express server
- MongoDB/PostgreSQL database
- RESTful API endpoints
- HTTPS with SSL certificate
```

### Option 2: Firebase Integration
```dart
// Firebase setup for Hybrid Athlete
- Real-time database
- Authentication included
- Free tier available
- Mobile-optimized
```

### Option 3: AWS S3 + API Gateway
```dart
// AWS setup
- S3 for data storage
- API Gateway for REST
- CloudFormation for deployment
- Enterprise-grade security
```

## Implementation Requirements

### API Endpoints Needed:
- `POST /sync` - Upload user data
- `GET /sync/:deviceId` - Download user data
- `GET /health` - Service status check
- `DELETE /sync/:deviceId` - Clear user data

### Data Structure:
```json
{
  "deviceId": "HA-12345678",
  "timestamp": "2024-01-07T10:30:00Z",
  "syncType": "full_sync",
  "version": "1.0",
  "platform": "ios",
  "data": {
    "workout_history": [...],
    "user_profile": {...},
    "earned_badges": [...],
    "weekly_goal": 5,
    // ... all other data fields
  }
}
```

## Security Considerations
- Device ID as primary key
- Data encryption at rest
- HTTPS required
- API key authentication
- Rate limiting
- Data retention policies

## Current Status
✅ **App ready for cloud sync**
✅ **Fallback service working**
✅ **Automatic detection of availability**
✅ **Bidirectional sync implemented**
⚠️ **Need to setup your cloud service**

## Next Steps
1. Choose your cloud provider
2. Set up the API endpoints
3. Update `_cloudBaseUrl` in `cloud_sync_service.dart`
4. Test with real data
5. Disable fallback service

## Testing the Current Setup
The app currently uses jsonbin.org as fallback. You can test immediately:
1. Enable cloud sync in device sync settings
2. Data will upload to the free service
3. Try syncing from another device
4. Works for testing/demo purposes

**Note**: Replace with your secure cloud service for production use!