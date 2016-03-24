//
//  ScoresData.m
//  Tunerval
//
//  Created by Sam Bender on 3/19/16.
//  Copyright © 2016 Sam Bender. All rights reserved.
//

#import "ScoresData.h"
#import "Constants.h"
#import <FMDB/FMDB.h>

@implementation ScoresData

+ (NSArray*) difficultyDataForInterval:(IntervalType)interval afterUnixTimestamp:(double)timestamp
{
    NSMutableArray *yVals = [[NSMutableArray alloc] init];
    
    FMResultSet *s = [[Constants dbConnection] executeQuery:@"SELECT * FROM answer_history"];
    while ([s next])
    {
        if ([s intForColumn:@"interval"] == interval
            && [s doubleForColumn:@"created_at"] > timestamp)
        {
            [yVals addObject:@([s doubleForColumn:@"difficulty"])];
        }
    }
    return yVals;
}

+ (NSArray*) runningAverageDifficultyAfterUnixTimeStamp:(double)timestamp
{
    NSMutableArray *yVals = [[NSMutableArray alloc] init];
    NSMutableDictionary *intervalScores = [[NSMutableDictionary alloc] init];
    [self fillDictionaryWithScores:intervalScores afterUnixTimestamp:timestamp];
    
    FMDatabase *db = [Constants dbConnection];
    FMResultSet *s = [db executeQuery:@"SELECT * FROM answer_history"];
    
    double count = 1.0;
    while ([s next])
    {
        if ([s doubleForColumn:@"created_at"] < timestamp)
        {
            continue;
        }
        
        [intervalScores setObject:@([s doubleForColumn:@"difficulty"])
                          forKey:@([s intForColumn:@"interval"])];
        [yVals addObject:@([self dictionaryAverage:intervalScores])];
    }
    
    [db close];
    
    return yVals;
}

+ (double) dictionaryAverage:(NSDictionary*)dict
{
    double sum = 0.0;
    for (NSNumber *key in dict)
    {
        NSNumber *value = dict[key];
        sum += [value doubleValue];
    }
    
    return sum / (double)dict.count;
}

+ (void) fillDictionaryWithScores:(NSMutableDictionary*)dict afterUnixTimestamp:(double)timestamp
{
    FMDatabase *db = [Constants dbConnection];
    
    for (NSInteger i = -12; i <= 12; i++)
    {
        NSString *query = [NSString stringWithFormat:
                           @"SELECT * FROM answer_history "
                           "WHERE interval = %d "
                           "AND created_at > %f "
                           "ORDER BY created_at ASC "
                           "LIMIT 1",
                           (int)i,
                           timestamp
                           ];
        
        FMResultSet *s = [db executeQuery:query];
        if ([s next])
        {
            [dict setObject:@([s doubleForColumn:@"difficulty"]) forKey:@(i)];
        }
        else
        {
            // [dict setObject:@(100.00) forKey:@(i)];
        }
    }
    
    [db close];
}

@end
