#import "MainViewController.h"
#import "Video.h"
#import "VideoViewController.h"

@import GoogleInteractiveMediaAds;

@interface MainViewController () <UIAlertViewDelegate, VideoViewControllerDelegate>

/// Storage point for videos.
@property(nonatomic, copy) NSArray<Video *> *videos;

// AdsLoader
@property(nonatomic, strong) IMAAdsLoader *adsLoader;

@end

@implementation MainViewController

// Set up the app.
- (void)viewDidLoad {
  [super viewDidLoad];
  [self initVideos];

  // AdsLoader
  // Re-use this IMAAdsLoader instance for the entire lifecycle of your app.
  self.adsLoader = [[IMAAdsLoader alloc] initWithSettings:nil];
}

// Populate the video array.
- (void)initVideos {
  self.videos = @[
    [[Video alloc] initWithTitle:@"Live stream"
                        assetKey:@"c-rArva4ShKVIAkNfy6HUQ"
                     networkCode:@"21775744923"
                          apiKey:@""
    ],
    [[Video alloc] initWithTitle:@"VOD Stream"
                 contentSourceId:@"2548831"
                         videoId:@"tears-of-steel"
                     networkCode:@"21775744923"
                          apiKey:@""]
  ];
}

// When an item is selected, set the video item on the VideoViewController.
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
  if ([[segue identifier] isEqualToString:@"showVideo"]) {
    NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
    Video *video = self.videos[indexPath.row];
    VideoViewController *destVC = (VideoViewController *)segue.destinationViewController;
    destVC.delegate = self;
    destVC.video = video;
    destVC.adsLoader = self.adsLoader;
  }
}

// Only allow one selection.
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

// Returns number of items to be presented in the table.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return self.videos.count;
}

// Sets the display info for each table row.
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell =
      [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
  Video *selectedVideo = self.videos[indexPath.row];
  cell.textLabel.text = selectedVideo.title;
  return cell;
}

// Standard override.
- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

#pragma mark VideoViewControllerDelegate

- (void)videoViewController:(VideoViewController *)viewController
         didReportSavedTime:(NSTimeInterval)savedTime
                   forVideo:(Video *)video {
  video.savedTime = savedTime;
}

@end
