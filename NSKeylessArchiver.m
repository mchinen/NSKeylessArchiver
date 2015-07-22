/* Copyright (c) 2006-2007 Christopher J. W. Lloyd

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#include <string.h>

#import "NSKeylessArchiver.h"

#define NSUnimplementedMethod() \
NSLog(@"Method %s is not implemented!", __FUNCTION__)

@implementation NSKeylessArchiver

-init {
   _data=[NSMutableData new];
   _bytes=[_data mutableBytes];
   _position=0;
   _pass=0;

    // was NSCreateHashTable(NSNonOwnedPointerHashCallBacks,0)
    _conditionals = [[NSHashTable alloc] initWithOptions:NSPointerFunctionsWeakMemory|NSPointerFunctionsObjectPointerPersonality capacity:0];
   _objects= [[NSHashTable alloc] initWithOptions:NSPointerFunctionsWeakMemory|NSPointerFunctionsObjectPointerPersonality capacity:0];
   _classes= [[NSHashTable alloc] initWithOptions:NSPointerFunctionsWeakMemory|NSPointerFunctionsObjectPointerPersonality capacity:0];

    // was NSCreateHashTable(NSObjectHashCallBacks,0);
    _cStrings= [[NSHashTable alloc] initWithOptions:NSPointerFunctionsStrongMemory|NSPointerFunctionsObjectPointerPersonality capacity:0];
    
   return self;
}

-(void)dealloc {
   [_data release];
   [_conditionals release];
   [_objects release];
   [_classes release];
   [_cStrings release];
   [super dealloc];
}

-(NSData *)data {
   return [[_data copy] autorelease];
}

+(NSData *)archivedDataWithRootObject:(id)rootObject {
   NSKeylessArchiver *archiver=[[[self allocWithZone:NULL] init] autorelease];

   [archiver encodeRootObject:rootObject];
   return [archiver data];
}

+(BOOL)archiveRootObject:rootObject toFile:(NSString *)path {
   NSData *data=[self archivedDataWithRootObject:rootObject];

   return [data writeToFile:path atomically:YES];
}

-(NSMutableData *)archiverData {
   return _data;
}

-(void)cannotEncodeType:(const char *)type {
   [NSException raise:@"NSKeylessArchiverCannotEncodeException"
               format:@"NSKeylessArchiver cannot encode type=%s",type];
}

-(void)_ensureLength:(NSUInteger)length {
   [_data setLength:[_data length]+length];
   _bytes=[_data mutableBytes];
}

-(void)_appendData:(NSData *)data {
   if(_pass==0)
    return;

   [_data appendData:data];
   _bytes=[_data mutableBytes];
   _position=[_data length];
}

-(void)_appendWordOne:(uint8_t)value {
   if(_pass==0)
    return;

   [self _ensureLength:1];
   _bytes[_position++]=value;
}

-(void)_appendWordTwo:(uint16_t)value {
   if(_pass==0)
    return;

   [self _ensureLength:2];
   _bytes[_position++]=(value>>8)&0xFF;
   _bytes[_position++]=value&0xFF;
}

-(void)_appendWordFour:(uint32_t)value {
   if(_pass==0)
    return;

   [self _ensureLength:4];
   _bytes[_position++]=(value>>24)&0xFF;
   _bytes[_position++]=(value>>16)&0xFF;
   _bytes[_position++]=(value>>8)&0xFF;
   _bytes[_position++]=value&0xFF;
}

-(void)_appendFloat:(float)value {
   [self _appendWordFour:NSConvertHostFloatToSwapped(value).v];
}

-(void)_appendWordEight:(uint64_t)value {
   if(_pass==0)
    return;

   [self _ensureLength:8];
   _bytes[_position++]=(value>>56)&0xFF;
   _bytes[_position++]=(value>>48)&0xFF;
   _bytes[_position++]=(value>>40)&0xFF;
   _bytes[_position++]=(value>>32)&0xFF;
   _bytes[_position++]=(value>>24)&0xFF;
   _bytes[_position++]=(value>>16)&0xFF;
   _bytes[_position++]=(value>>8)&0xFF;
   _bytes[_position++]=value&0xFF;
}


- (void)_appendReference: (void *)value {
#ifdef __LP64__
	[self _appendWordEight: (uint64_t)value];
#else
	[self _appendWordFour: (uint32_t)value];
#endif
}


-(void)_appendBytes:(const uint8_t *)bytes length:(NSUInteger)length {
   int i;

   if(_pass==0)
    return;

   [self _ensureLength:length];
   for(i=0;i<length;i++)
    _bytes[_position++]=bytes[i];
}

-(void)_appendCStringBytes:(const char *)cString {
   [self _ensureLength:strlen(cString)+1];

   for(;*cString!='\0';cString++)
    _bytes[_position++]=*cString;

   _bytes[_position++]='\0';
}


- (void)_appendCString:(const char *)cString
{
    NSString *string, *lookup;

    if (_pass == 0) {
        return;
    }

    //NSLog(@"cString=%s", cString);
    string = [NSString stringWithUTF8String:cString];
    //NSLog(@"string=%@", string);

    if ((lookup = [_cStrings member:string]) != nil) {
        [self _appendReference:lookup];
    } else {
        [_cStrings addObject:string];

        [self _appendReference:string];
        [self _appendCStringBytes:[string UTF8String]];
    }
}


- (void)_appendClassVersion:(Class)class
{
    if (class == [NSObject class]) {
        // this is a ref, it can be 8 or 4 bytes depending on arch.
        [self _appendReference:(void *)0];
        return;
    }
    
    [self _appendReference:class];

    if ([_classes member:class] == NULL)
    {
        [_classes addObject:class];
        [self _appendCString:[NSStringFromClass(class) UTF8String]];
        [self _appendWordFour:[class version]];
        [self _appendClassVersion:[class superclass]];
    }
}


- (void)_appendObject:(id)object conditional:(BOOL)conditional
{
    if (_pass == 0) {
        if (object != nil) {
            //NSLog(@"%@ conditional=%s", NSStringFromClass([object class]), conditional ? "YES" : "NO");

            if (!conditional) {
                if ([_conditionals member:object] == NULL) {
                    [_conditionals addObject:object];
                    [object encodeWithCoder:self];
                }
            }
        }
    } else {
        if (conditional && ([_conditionals member:object] == NULL)) {
            object=nil;
        }

        if (object == nil) {
            [self _appendWordFour:0];
        } else if ([_objects member:object] != NULL) {
            [self _appendReference:object];
        } else { // FIX do replacementForCoder ?
            Class class = [object classForArchiver];

            [_objects addObject:object];

            [self _appendReference:object];
            [self _appendClassVersion:class];

            [object encodeWithCoder:self];
        }
    }
}


-(void)_appendArrayOfObjCType:(const char *)type length:(NSUInteger)length
  at:(const void *)addr {

   if(_pass==0)
    return;

   switch(*type){
    case 'c':
    case 'C':{
      const unsigned char *values=addr;
      NSInteger i;

      for(i=0;i<length;i++)
       [self _appendWordOne:values[i]];
     }
     break;

    case 's':
    case 'S':{
      const unsigned short *values=addr;
      NSInteger i;

      for(i=0;i<length;i++)
       [self _appendWordTwo:values[i]];
     }
     break;

    default:
     [self cannotEncodeType:type];
     break;
   }
}

-(void)encodeValueOfObjCType:(const char *)type at:(const void *)addr {
   //NSLog(@"type=%s",type);

   [self _appendCString:type];

   switch(*type){
    case 'c':
    case 'C':{
      unsigned char value=*(const unsigned char *)addr;
      [self _appendWordOne:value];
     }
     break;

    case 's':
    case 'S':{
      unsigned short value=*(const unsigned short *)addr;
      [self _appendWordTwo:value];
     }
     break;

    case 'i':
    case 'I':{
      unsigned int value=*(const unsigned int *)addr;
      [self _appendWordFour:value];
     }
     break;

    case 'l':
    case 'L':{
      unsigned long value=*(const unsigned long *)addr;
      [self _appendWordFour:value];
     }
     break;

    case 'q':
    case 'Q':{
      unsigned long long value=*(const unsigned long long *)addr;
      [self _appendWordEight:value];
     }
     break;

    case 'f':{
      float value=*(const float *)addr;
      [self _appendFloat:value];
     }
     break;

    case 'd':{
      double value=*(const double *)addr;
      [self _appendWordEight:NSConvertHostDoubleToSwapped(value).v];
     }
     break;

    case '*':{
      const char * const *cString=addr;

      [self _appendCString:*cString];
     }
     break;

    case '@':{
      id object=*(const id *)addr;

      [self _appendObject:object conditional:NO];
     }
     break;

    case '#':
     [self cannotEncodeType:type];
     break;

    case ':':{
      SEL selector=*(const SEL *)addr;

      [self _appendCString:sel_getName(selector)];
     }
     break;

    case '[':{
      const char *tmp=type;
      unsigned    length=0;

      tmp++; // skip [
      for(;*tmp>='0' && *tmp<='9';tmp++)
       length=(length*10)+(*tmp-'0');

      [self _appendArrayOfObjCType:tmp length:length at:addr];
     }
     break;

    case '{': // this is extremely lame
     if(strcmp(type,@encode(NSRange))==0){
      NSRange value=*(const NSRange *)addr;

      [self _appendWordFour:value.location];
      [self _appendWordFour:value.length];
      break;
     }
     if(strcmp(type,@encode(CGPoint))==0){
      CGPoint value=*(const CGPoint *)addr;

      [self _appendFloat:value.x];
      [self _appendFloat:value.y];
      break;
     }
     if(strcmp(type,@encode(CGSize))==0){
      CGSize value=*(const CGSize *)addr;

      [self _appendFloat:value.width];
      [self _appendFloat:value.height];
      break;
     }
     if(strcmp(type,@encode(CGRect))==0){
      CGRect value=*(const CGRect *)addr;

      [self _appendFloat:value.origin.x];
      [self _appendFloat:value.origin.y];
      [self _appendFloat:value.size.width];
      [self _appendFloat:value.size.height];
      break;
     }
     [self cannotEncodeType:type];
     break;

    case '(':
    case 'b':
    case '^':
    case '?':
    default:
     [self cannotEncodeType:type];
     break;
   }

}

-(void)encodeBytes:(const void *)byteaddr length:(NSUInteger)length {
   [self _appendWordFour:length];
   [self _appendBytes: byteaddr length:length];
}

-(void)encodeDataObject:(NSData *)data {
   [self cannotEncodeType:"encodeDataObject"];
}

#define NSKEYLESSARCHIVER_VERSION (1)

-(void)encodeRootObject:(id)rootObject {
   _position=0;
   _pass=0;
   [self _appendObject:rootObject conditional:NO];
   if(_position!=0)
    NSLog(@"_position=%d",_position);

    if([_conditionals member:rootObject]==NULL)
    NSLog(@"rootObject not in conditionals");

   _position=0;
   _pass=1;
   [self _appendCStringBytes:"~V1~"];
   [self _appendWordFour:NSKEYLESSARCHIVER_VERSION]; // archive version
    
   /* NSKEYLESSARCHIVER_VERSION >= 1 */
#ifdef __LP64__
    NSLog(@"encoding 64 bit");
   [self _appendWordFour:1]; // LP64 encoded
#else
    
    NSLog(@"encoding 32 bit");
   [self _appendWordFour:0]; // not LP64 encoded
#endif
   
 

   [self _appendCString:"@"];
   [self _appendObject:rootObject conditional: NO];
}

-(void)encodeConditionalObject:(id)object {
   [self _appendCString:"@"];
   [self _appendObject:object conditional:YES];
}

-(void)encodeClassName:(NSString *)runtime intoClassName:(NSString *)archive {
   NSUnimplementedMethod();
}

-(void)replaceObject:original withObject:replacement {
   NSUnimplementedMethod();
}

@end

