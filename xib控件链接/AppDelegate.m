//
//  AppDelegate.m
//  xib控件链接
//
//  Created by ljh on 14-9-24.
//  Copyright (c) 2014年 LJH. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property(strong,nonatomic)NSMutableDictionary* dic;

@property(strong,nonatomic)NSString* space;
@property NSRange connRange;
@end

@implementation AppDelegate


-(void)replaceFileWithDir:(NSString*)dir
{
    NSArray* array = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil];
    for (NSString* fileName in array)
    {
        NSString* newPath = [dir stringByAppendingPathComponent:fileName];
        BOOL isDir;
        [[NSFileManager defaultManager] fileExistsAtPath:newPath isDirectory:&isDir];
        if(isDir)
        {
            [self replaceFileWithDir:newPath];
        }
        else if([newPath.pathExtension.lowercaseString isEqualToString:@"xib"])
        {
            [self replaceFileWithPath:newPath];
        }
    }
}

-(void)replaceFileWithPath:(NSString*)path
{
    NSMutableString* fileContent = [NSMutableString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    
    NSRange crange = [self findConnectionIndex:fileContent];
    if(crange.length == 0)
    {
        [_dic setObject:@"" forKey:path];
        return;
    }
    
    int offset = 0;
    NSString *regularStr = @"\"(?:(\\\\\"|[^\"]|[\\r\\n]))*\"";
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:regularStr options:NSRegularExpressionAllowCommentsAndWhitespace error:nil];
    NSArray* mat1 = [regex matchesInString:fileContent.lowercaseString options:0 range:NSMakeRange(0, fileContent.length)];
    BOOL hasChange = NO;

    NSString *regul2 = @"<string key=\"text\">[^<>]*</string>";
    NSRegularExpression* regex2 = [NSRegularExpression regularExpressionWithPattern:regul2 options:NSRegularExpressionAllowCommentsAndWhitespace error:nil];
    NSArray* mat2 = [regex2 matchesInString:fileContent.lowercaseString options:0 range:NSMakeRange(0, fileContent.length)];
    
    NSMutableArray* matches = [NSMutableArray arrayWithArray:mat1];
    [matches addObjectsFromArray:mat2];
    
    int ppp = 0;
    for (NSTextCheckingResult *match in matches)
    {
        ppp ++;
        
        NSRange range = [match range];
        if (crange.location < range.location)
        {
            range.location += offset;
        }
        
        NSString* subStr = [fileContent substringWithRange:range];
        
        BOOL zhongwen = NO;
        for(int i=0; i< subStr.length;i++){
            int a = [subStr characterAtIndex:i];
            if( a > 0x4e00 && a < 0x9fff)
            {
                zhongwen = YES;
            }
        }
        if(zhongwen == NO)
        {
            continue;
        }

        NSString* pname = nil;
        NSString* name = nil;
        NSUInteger left = 0;
        if([subStr hasPrefix:@"<string key=\"text\">"])
        {
            subStr = [subStr substringWithRange:NSMakeRange(@"<string key=\"text\">".length, subStr.length - @"<string key=\"text\">".length - @"</string>".length)];
            name = @"label";
            pname = @"text";
            
            left = [fileContent rangeOfString:@"<label" options:NSBackwardsSearch  range:NSMakeRange(0, range.location)].location + 1;
        }
        else
        {
            NSUInteger pll = [fileContent rangeOfString:@" " options:NSBackwardsSearch range:NSMakeRange(0, range.location)].location + 1;
            pname = [fileContent substringWithRange:NSMakeRange(pll, range.location - pll - 1)];
            
            
            left = [fileContent rangeOfString:@"<" options:NSBackwardsSearch range:NSMakeRange(0, range.location)].location + 1;
            NSUInteger llen = [fileContent rangeOfString:@" " options:0 range:NSMakeRange(left, range.location-left)].location - left;
            
            name = [fileContent substringWithRange:NSMakeRange(left, llen)];
            if([name isEqualToString:@"state"])
            {
                left = [fileContent rangeOfString:@"<button" options:NSBackwardsSearch  range:NSMakeRange(0, left)].location + 1;
                name = @"button";
            }
        }
        
        NSUInteger idindex = [fileContent rangeOfString:@"id=\"" options:0 range:NSMakeRange(left, fileContent.length - left)].location + 4;
        NSUInteger idlength = [fileContent rangeOfString:@"\"" options:0 range:NSMakeRange(idindex, fileContent.length-idindex)].location - idindex;
        
        NSString* idname = [fileContent substringWithRange:NSMakeRange(idindex, idlength)];
 
        NSString* linkName = nil;
        NSString*  ccont = [fileContent substringWithRange:crange];
        NSRange cid = [ccont rangeOfString:[NSString stringWithFormat:@"destination=\"%@\"",idname]];
        if (cid.length > 0)
        {
             NSUInteger linkLeft = [ccont rangeOfString:@"property=\"" options:NSBackwardsSearch range:NSMakeRange(0, cid.location)].location + @"property=\"".length;
             NSUInteger linkLength = [ccont rangeOfString:@"\"" options:0 range:NSMakeRange(linkLeft, cid.location - linkLeft)].location - linkLeft;
            linkName = [ccont substringWithRange:NSMakeRange(linkLeft, linkLength)];
        }
        else
        {
            linkName = [NSString stringWithFormat:@"auto_%d_%@",ppp,name];
            NSString* newCon = [NSString stringWithFormat:@"<outlet property=\"%@\" destination=\"%@\" id=\"aaa-aa-%.3d\"/>%@",linkName,idname,ppp,_space];
            
            [fileContent insertString:newCon atIndex:crange.location];

            crange.length += newCon.length;
            offset += newCon.length;
            
            BOOL AA = [self updateHFileWihtXibPath:path vname:name linkName:linkName text:subStr pname:pname];
            if (AA)
            {
                hasChange = YES;
            }
        }
        [self updateMFileWihtXibPath:path vname:name linkName:linkName text:subStr pname:pname];
        
    }
    NSLog(@"%@ ok \n",path);
    if(hasChange)
    {
        [fileContent writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}
-(NSRange)findConnectionIndex:(NSMutableString*)content
{
    NSUInteger index = 0;
    while (true)
    {
        NSRange range = [content rangeOfString:@"<connections>" options:0 range:NSMakeRange(index, content.length-index)];
        if(range.length == 0)
        {
            break;
        }
        NSUInteger left = range.location + range.length;
        NSUInteger length = [content rangeOfString:@"</connections>" options:0 range:NSMakeRange(left, content.length - left)].location - left;
        
        NSString* conn = [content substringWithRange:NSMakeRange(left, length)];
        if([conn rangeOfString:@"destination=\"-1\""].length > 0 || [conn rangeOfString:@"<outlet property"].length == 0)
        {
            index = left + length + 8;
        }
        else
        {
            NSRange temp = [conn rangeOfString:@"<"];
            if(temp.length == 0)
            {
                _space = @"\n";
                return NSMakeRange(left, length);
            }
            else
            {
                _space = [conn substringWithRange:NSMakeRange(0, temp.location)];
                return NSMakeRange(left + temp.location, length - temp.location);
            }
        }
    }
    
    return NSMakeRange(0, 0);
}
-(BOOL)updateHFileWihtXibPath:(NSString*)xibPath vname:(NSString*)vName linkName:(NSString*)linkName text:(NSString*)text pname:(NSString*)pname
{
    NSString* hpath = [xibPath stringByReplacingOccurrencesOfString:@".xib" withString:@".h"];
    if([[NSFileManager defaultManager] fileExistsAtPath:hpath] == NO)
    {
        return NO;
    }
    
    NSMutableString* hcontent = [NSMutableString stringWithContentsOfFile:hpath encoding:NSUTF8StringEncoding error:nil];
    NSUInteger index = [hcontent rangeOfString:@"@end" options:NSBackwardsSearch range:NSMakeRange(0, hcontent.length)].location;
    
    NSString* typename = [NSString stringWithFormat:@"UI%@",vName.capitalizedString];
    NSString* newout = [NSString stringWithFormat:@"@property(weak, nonatomic) IBOutlet %@ *%@;\n",typename,linkName];
    
    [hcontent insertString:newout atIndex:index];
    [hcontent writeToFile:hpath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    return YES;
}
-(void)updateMFileWihtXibPath:(NSString*)xibPath vname:(NSString*)vName linkName:(NSString*)linkName text:(NSString*)text pname:(NSString*)pname
{
    NSString* mpath = [xibPath stringByReplacingOccurrencesOfString:@".xib" withString:@".m"];
    if([[NSFileManager defaultManager] fileExistsAtPath:mpath] == NO)
    {
        [_dic setObject:@"" forKey:xibPath];
        return;
    }
    NSMutableString* content = [NSMutableString stringWithContentsOfFile:mpath encoding:NSUTF8StringEncoding error:nil];
    
    NSRange sy_range = [content rangeOfString:@"(void)initTextXib"];
    NSUInteger inserindex = 0;
    if(sy_range.length > 0)
    {
        sy_range.length = content.length - sy_range.location;
        inserindex = [content rangeOfString:@"{" options:0 range:sy_range].location + 1;
        
    }
    else
    {
        sy_range = [content rangeOfString:@"(void)awakeFromNib"];
        if(sy_range.length > 0)
        {
            sy_range.length = content.length - sy_range.location;
            inserindex = [content rangeOfString:@"{" options:0 range:sy_range].location + 1;
        }
        
    }
    NSString* insertText = nil;
    if([vName isEqualToString:@"button"])
    {
        insertText = [NSString stringWithFormat:@"\n    [self.%@ lkTitle:@%@];\n",linkName,text];
    }
    else
    {
        insertText = [NSString stringWithFormat:@"\n    self.%@.%@ = @%@;\n",linkName,pname,text];
    }
    if(inserindex == 0)
    {
        NSUInteger iii = [content rangeOfString:@"@end" options:NSBackwardsSearch range:NSMakeRange(0, content.length)].location;
        
        NSString* lastSuff = mpath.lastPathComponent.lowercaseString;
        if([lastSuff hasSuffix:@"vc.m"] || [lastSuff hasSuffix:@"controller.m"] || [lastSuff hasSuffix:@"ctl.m"])
        {
            [content insertString:@"- (void)initTextXib\n{" atIndex:iii];
            
            iii = [content rangeOfString:@"@end" options:NSBackwardsSearch range:NSMakeRange(0, content.length)].location;
            [content insertString:[NSString stringWithFormat:@"%@\n    [super initTextXib];\n}\n",insertText] atIndex:iii];
        }
        else
        {
            [content insertString:@"- (void)awakeFromNib\n{" atIndex:iii];
            
            iii = [content rangeOfString:@"@end" options:NSBackwardsSearch range:NSMakeRange(0, content.length)].location;
            [content insertString:[NSString stringWithFormat:@"%@\n    [super awakeFromNib];\n}\n",insertText] atIndex:iii];
        }
    }
    else
    {
        if([content rangeOfString:insertText options:0 range:NSMakeRange(inserindex, content.length - inserindex)].length > 0)
        {
            return;
        }
        [content insertString:insertText atIndex:inserindex];
    }
    
    [content writeToFile:mpath atomically:YES encoding:NSUTF8StringEncoding error:nil];
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.dic = [NSMutableDictionary dictionary];
    ///目錄
    NSString* dirPath = @"/Users/linyunfeng/Documents/code_git/work4/iPhone/Meetyou_iPhone/Seeyou/Seeyou";
    [self replaceFileWithDir:dirPath];
    
    NSMutableString* sb = [NSMutableString string];
    [_dic enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [sb appendFormat:@"\%@\n",key];
    }];
    
    [sb writeToFile:[dirPath stringByAppendingPathComponent:@"xxxx.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
