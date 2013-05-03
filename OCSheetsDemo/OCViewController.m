//
//  OCViewController.m
//  OCSheets
//
//  Created by Ben Pilcher on 5/2/13.
//  Copyright (c) 2013 Pearson Education. All rights reserved.
//

#import "OCViewController.h"

@interface OCViewController ()

@end

@implementation OCViewController

- (id)init
{
    self = [super initWithNibName:@"OCView" bundle:nil];
    if (self){
        //
    }
    
    return self;
}
- (id)initWithNibName:(NSString *)n bundle:(NSBundle *)b
{
    return [self init];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
