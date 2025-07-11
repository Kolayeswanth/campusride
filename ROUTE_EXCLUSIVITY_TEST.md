# Route Exclusivity Feature Test Guide

## Overview
This document outlines how to test the new route exclusivity feature where routes in use by other drivers are shown as disabled cards with "Trip ongoing..." message.

## What Changed
1. **TripService**: Modified `_filterAvailableRoutes` to `_markRoutesInUse` - now marks routes as in use instead of filtering them out completely
2. **BusRoute Model**: Added `isInUseByOther` property to track route availability  
3. **Driver Home Screen**: Updated UI to show disabled cards for routes in use by other drivers
4. **Visual Indicators**: Routes in use show orange "In Use" badge, grayed appearance, and "Trip ongoing by another driver" message

## Test Scenarios

### Setup
1. Ensure you have at least 2 driver accounts
2. Make sure both drivers belong to the same college 
3. Have at least 1 route available for that college

### Test 1: Normal Route Display
1. Login as Driver A
2. Navigate to driver home screen
3. **Expected**: All available routes show normally with blue primary color and "Active" badge

### Test 2: Route Exclusivity When Another Driver Starts Trip
1. **Driver A**: Login and start a trip on Route X
2. **Driver B**: Login and navigate to driver home screen  
3. **Expected**: 
   - Route X should appear as a disabled card
   - Card should have reduced opacity (60%)
   - Orange "In Use" badge instead of green "Active" 
   - Orange tint overlay on the card
   - Text should say "Trip ongoing by another driver"
   - Lock icon instead of visibility icon

### Test 3: Attempting to Use Route in Use
1. **Driver B**: Tap on the disabled route card
2. **Expected**: 
   - SnackBar appears saying "This route is currently being used by another driver"
   - Navigation to route details should NOT occur

### Test 4: Route Becomes Available Again
1. **Driver A**: End the trip on Route X
2. **Driver B**: Pull to refresh the driver home screen
3. **Expected**: 
   - Route X should now appear normal again
   - Blue primary color, "Active" badge
   - Can tap to navigate to route details

### Test 5: Database Level Prevention  
1. **Driver B**: Manually try to start a trip on a route in use (via API/database)
2. **Expected**: 
   - `startDriverTrip` should throw exception
   - Error message: "This route is currently being used by another driver. Please select a different route."

## UI Visual Indicators

### Normal Route Card
- **Badge**: Green "Active" or Gray "Inactive"
- **Route Name**: Blue primary color background
- **Opacity**: 100%
- **Icon**: Eye icon with "Tap for ride details"
- **Interaction**: Fully interactive

### Route In Use Card  
- **Badge**: Orange "In Use"
- **Route Name**: Gray background  
- **Opacity**: 60%
- **Icon**: Lock icon with "Trip ongoing by another driver"
- **Overlay**: Orange tint (10% opacity)
- **Interaction**: Shows SnackBar message, no navigation

## Backend Verification

### Database Queries to Verify
```sql
-- Check active trips
SELECT driver_id, route_id, status, created_at 
FROM driver_trips 
WHERE status = 'active';

-- Check if specific route is in use
SELECT COUNT(*) as active_count
FROM driver_trips 
WHERE route_id = 'your-route-id' AND status = 'active';
```

### Service Method Calls
- `TripService._isRouteCurrentlyInUse(routeId)` should return `true` for routes with active trips
- `TripService._markRoutesInUse(routes)` should properly mark `isInUseByOther` flag

## Troubleshooting

### Routes Not Showing as Disabled
1. Check that both drivers belong to same college
2. Verify the active trip exists in database
3. Pull to refresh to ensure latest data
4. Check console logs for "Route status:" debug messages

### Error Messages Not Appearing  
1. Verify SnackBar implementation in `_showRouteInUseMessage()`
2. Check that `isInUseByOther` flag is properly set
3. Ensure UI state updates correctly

### Database Issues
1. Run the `URGENT_DATABASE_FIX.sql` migration if route_id column type issues persist
2. Verify college-route relationships are properly set up
3. Check that college filtering logic works correctly

## Success Criteria
✅ Routes in use by other drivers appear as visually distinct disabled cards  
✅ Attempting to use an in-use route shows appropriate error message  
✅ Routes become available again when trips end  
✅ Database prevents multiple drivers on same route  
✅ UI provides clear visual feedback about route availability  
✅ Performance remains good with the new exclusivity checks

## Notes
- The exclusivity check runs every time routes are fetched
- Visual feedback is immediate based on the `isInUseByOther` flag
- The system gracefully handles network errors by showing all routes as available
- Refresh functionality works properly to update route status
