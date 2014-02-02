//
//  FCViewController.m
//  Forecastr
//
//  Created by Rob Phillips on 4/3/13.
//  Copyright (c) 2013 Rob Phillips. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "FCViewController.h"
#import "Forecastr.h"
#import "FCPlaylistTableViewController.h"

static float kDemoLatitude = 45.5081; // South is negative
static float kDemoLongitude = -73.5550; // West is negative
static double kDemoDateTime = 1364991687; // EPOCH time

float currentLatitude, currentLongitude;

@interface FCViewController () <CLLocationManagerDelegate>
{
    Forecastr *forecastr;
    
}

@property (nonatomic, strong) CLLocationManager* locationManager;

@property (nonatomic, strong) NSMutableDictionary* params;

@property (nonatomic, strong) NSMutableArray* playlistArtists;
@property (nonatomic, strong) NSArray* playlistSongs;
@property (nonatomic, strong) NSMutableArray* playlistSongTitles;

@property (nonatomic, strong) NSDictionary* forecastJSON;
@property (nonatomic, strong) NSMutableArray* moodTags;

@property (nonatomic, strong) AFHTTPRequestOperationManager* manager;

@end



@implementation FCViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.playlistArtists = [[NSMutableArray alloc] init];
    self.playlistSongTitles = [[NSMutableArray alloc] init];
    
    self.params = [[NSMutableDictionary alloc] init];
    self.moodTags = [[NSMutableArray alloc] init];
    
    [self startStandardUpdates];
	
    // Get a reference to the Forecastr singleton and set the API key
    // (You only have to set the API key once since it's a singleton)
    forecastr = [Forecastr sharedManager];
    forecastr.apiKey = @"a64e6cae035b2f63cdeebca5414fb31b";
    
    [self performSelector:@selector(forecastWithExclusions) withObject:nil afterDelay:5.0];
    
    self.manager = [AFHTTPRequestOperationManager manager];

    [self.params setValue:@"tagseed" forKey:@"fct"];
    [self.params setValue:@"json" forKey:@"format"];
    
    [self setTheMood];
    
    NSLog(@"Search paramaters are: %@", self.params);
    
    NSMutableString* queryString = [[NSMutableString alloc] init];
    [self buildQueryString:queryString];
    
    NSLog(@"this is the query string %@", queryString);
    
    
    [self.manager GET:queryString parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"This is the request URL: %@", operation.request);
        NSLog(@"This is the response object %@", responseObject);
        self.playlistSongs = [[[responseObject objectForKey:@"root"] objectForKey:@"tracks"] objectForKey:@"track"];
        NSLog(@"The second song in the playliast is: %@", [self.playlistSongs[1] objectForKey:@"title"]);
        
        [self scrapeTitles:self.playlistSongs];
        [self scrapeArtists:self.playlistSongs];
        
        NSLog(@"The playlist songs are: %@", self.playlistSongTitles);
        NSLog(@"The playlist artists are: %@", self.playlistArtists);
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"%@", error);
    }];
}

- (void)startStandardUpdates
{
    // Create the location manager if this object does not
    // already have one.
    
    if (nil == self.locationManager)
        self.locationManager = [[CLLocationManager alloc] init];
    
    self.locationManager.delegate = self;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyKilometer;
    
    // Set a movement threshold for new events.
    self.locationManager.distanceFilter = 500; // meters
    
    [self.locationManager startUpdatingLocation];
}

- (void)scrapeTitles:(NSArray*)tracks
{
    for (int i = 0; i<[tracks count]; i++) {
//        NSLog(@"%@",[tracks[i] objectForKey:@"title"]);
        [self.playlistSongTitles addObject: [tracks[i] objectForKey:@"title"]];
    }
}

- (void)scrapeArtists:(NSArray*)tracks
{
    for (int i = 0; i<[tracks count]; i++) {
//        NSLog(@"%@", [[tracks[i] objectForKey:@"artist"] objectForKey:@"name"]);
        [self.playlistArtists addObject:[[tracks[i] objectForKey:@"artist"] objectForKey:@"name"]];
    }
}

- (void)setTheMood
{
    if ([self.forecastJSON[@"apparentTemperature"] integerValue] <= 40) {
        [self.moodTags addObject:@"cool"];
    } else if ([self.forecastJSON[@"apparentTemperature"] integerValue] >= 80) {
        [self.moodTags addObject:@"downtempo"];
    }
    
    if ([self.forecastJSON[@"cloudCover"] floatValue] <= .1) {
        [self.moodTags addObject:@"hopeful"];
        [self.moodTags addObject:@"happy"];
    } else if ([self.forecastJSON[@"cloudCover"] floatValue] >= .8) {
        [self.moodTags addObject:@"melancholic"];
    }
    
    if ([self.forecastJSON[@"windSpeed"] floatValue] >= 30) {
        [self.moodTags addObject:@"angry"];
    } else if ([self.forecastJSON[@"windSpeed"] floatValue] >= 50) {
        [self.moodTags addObject:@"threatening"];
    } else if ([self.forecastJSON[@"windSpeed"] floatValue] <= 3) {
        [self.moodTags addObject:@"zen"];
    }
    
    [self.params setObject:self.moodTags forKey:@"tag"];
}

-(void)buildQueryString:(NSMutableString*)baseURL {
    [baseURL appendString:@"http://musicovery.com/api/playlist.php?fct=tagseed&format=json"];
    for(NSString* mood in self.moodTags) {
        [baseURL appendString:@"&tag="];
        [baseURL appendString: mood];
    }
}

// Delegate method from the CLLocationManagerDelegate protocol.
- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray *)locations {
    // If it's a relatively recent event, turn off updates to save power.
    CLLocation* location = [locations lastObject];
    NSDate* eventDate = location.timestamp;
    NSTimeInterval howRecent = [eventDate timeIntervalSinceNow];
    if (abs(howRecent) < 15.0) {
        // If the event is recent, do something with it.
        NSLog(@"latitude %+.6f, longitude %+.6f\n",
              location.coordinate.latitude,
              location.coordinate.longitude);
        currentLatitude = location.coordinate.latitude;
        currentLongitude = location.coordinate.longitude;
    }
}

// Kick off asking for weather data for Montreal on 2013-04-03 12:21:27 +0000
- (void)forecastWithTime
{
    [forecastr getForecastForLatitude:kDemoLatitude longitude:kDemoLongitude time:[NSNumber numberWithDouble:kDemoDateTime] exclusions:nil extend:nil success:^(id JSON) {
        NSLog(@"JSON Response (for %@) was: %@", [NSDate dateWithTimeIntervalSince1970:kDemoDateTime], JSON);
    } failure:^(NSError *error, id response) {
        NSLog(@"Error while retrieving forecast: %@", [forecastr messageForError:error withResponse:response]);
    }];
}

// Kick off asking for weather while specifying exclusions
// Currently, the exclusions can be: currently, minutely, hourly, daily, alerts, flags
- (void)forecastWithExclusions
{
    NSArray *tmpExclusions = @[kFCAlerts, kFCFlags, kFCMinutelyForecast, kFCHourlyForecast, kFCDailyForecast];
    [forecastr getForecastForLatitude:currentLatitude longitude:currentLongitude time:nil exclusions:tmpExclusions extend:nil success:^(id JSON) {
        NSLog(@"JSON Response was: %@", JSON);
        self.forecastJSON = [[NSMutableDictionary alloc] initWithDictionary: JSON[@"currently"]];
        NSLog(@"%@", self.forecastJSON);
    } failure:^(NSError *error, id response) {
        NSLog(@"Error while retrieving forecast: %@", [forecastr messageForError:error withResponse:response]);
    }];
}
- (IBAction)generatePlaylistButtonPressed:(id)sender {
    [self performSegueWithIdentifier:@"PlaylistSegue" sender:self];
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Make sure your segue name in storyboard is the same as this line
    if ([[segue identifier] isEqualToString:@"PlaylistSegue"])
    {
        // Get reference to the destination view controller
        FCPlaylistTableViewController *pTVC = [segue destinationViewController];
        
        // Pass any objects to the view controller here, like...
        pTVC.songs = self.playlistSongTitles;
        pTVC.artists = self.playlistArtists;
    }
}

// Kick off asking for weather while specifying exclusions, SI units, and JSONP callback
- (void)forecastWithMultipleOptions
{
    forecastr.units = kFCSIUnits;
    forecastr.callback = @"someJavascriptFunctionName";
    NSArray *tmpExclusions = @[kFCAlerts, kFCFlags, kFCMinutelyForecast, kFCHourlyForecast, kFCDailyForecast];
    [forecastr getForecastForLatitude:kDemoLatitude longitude:kDemoLongitude time:nil exclusions:tmpExclusions extend:nil success:^(id JSON) {
        NSLog(@"JSON Response (w/ SI units, JSONP callback, and exclusions: %@) was: %@", tmpExclusions, JSON);
    } failure:^(NSError *error, id response) {
        NSLog(@"Error while retrieving forecast: %@", [forecastr messageForError:error withResponse:response]);
    }];
    forecastr.callback = nil;
}

@end
