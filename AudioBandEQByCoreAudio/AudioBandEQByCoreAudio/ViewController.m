//
//  ViewController.m
//  AudioBandEQByCoreAudio
//
//  Created by ren zhicheng on 2017/6/13.
//  Copyright © 2017年 renzhicheng. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
//中心频率数组
@property(nonatomic, strong)NSArray *centreFrequencyArray;
@property(nonatomic, strong)UISegmentedControl *modelSelector;



@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    //中心频率几乎成倍增长
    self.centreFrequencyArray = @[@32, @64, @125, @250, @500, @1000, @2000, @4000, @8000, @16000];
    
    for (int i = 0; i < _centreFrequencyArray.count; i++) {
        UILabel *fqLabel = [[UILabel alloc] initWithFrame:CGRectMake(5, 100 + i * 40,90, 40)];
        fqLabel.textAlignment = NSTextAlignmentRight;
        fqLabel.text = [NSString stringWithFormat:@"%@ HZ",_centreFrequencyArray[i]];
        [self.view addSubview:fqLabel];
        
        UISlider *fqSlider = [[UISlider alloc]initWithFrame:CGRectMake(105, 100 + i * 40, 230, 40)];
        fqSlider.value = 0;
        fqSlider.minimumValue = -12;
        fqSlider.maximumValue = 12;
        fqSlider.tag = i + 1;
        [fqSlider addTarget:self action:@selector(fqSliderValueChanged:) forControlEvents:UIControlEventValueChanged];
        [self.view addSubview:fqSlider];
        
    }
    NSArray *modelArray = @[@"低音",@"人声",@"流行",@"摇滚",@"电子",@"古典",@"金属",@"无"];
    UISegmentedControl *modelSelector = [[UISegmentedControl alloc] initWithItems:modelArray];
    modelSelector.frame = CGRectMake(3, 550, self.view.frame.size.width - 6, 45);
    [modelSelector addTarget:self action:@selector(fqSelectorValueChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:modelSelector];
    
    
}

- (void)fqSliderValueChanged:(UISlider *)sender {
    
}

- (void)fqSelectorValueChanged:(UISegmentedControl *)sender {
    
}
@end
