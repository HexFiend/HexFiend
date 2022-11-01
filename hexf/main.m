//
//  main.m
//  hexf
//
//  Created by Kevin Wojniak on 9/24/17.
//  Copyright © 2017 ridiculous_fish. All rights reserved.
//

#import "Controller.h"

int main(int argc __unused, const char * argv[] __unused) {
    @autoreleasepool {
        Controller *controller = [[Controller alloc] init];
        NSArray<NSString *> *args = [[NSProcessInfo processInfo] arguments];
        if (args.count <= 1) {
            if ([controller processStandardInput]) {
                return EXIT_SUCCESS;
            } else {
                return [controller printUsage];
            }
        }
        return [controller processArguments:args];
    }
    return EXIT_SUCCESS;
}
