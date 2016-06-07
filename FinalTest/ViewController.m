//
//  ViewController.m
//  FinalTest
//
//  Created by Ofer Mano on 08/05/2016.
//  Copyright © 2016 Lightricks. All rights reserved.
//

#import "ViewController.h"

#import "MetalTests.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  [MetalTests metalTest];
  // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

@end
