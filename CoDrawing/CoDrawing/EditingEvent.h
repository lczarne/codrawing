//
//  EditingEvent.h
//  CoDrawing
//
//  Created by Łukasz Czarnecki on 9/25/13.
//  Copyright (c) 2013 Łukasz Czarnecki. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EditingEvent : NSObject

@property (nonatomic, strong) id eventObject;
@property int eventType;
@property int identifier;

@end
