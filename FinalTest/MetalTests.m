// Copyright (c) 2016 Lightricks. All rights reserved.
// Created by Ofer Mano.

#import "MetalTests.h"


@implementation MetalTests

+ (void)metalTest {
  // Create two libraries one with dummy function and one without.
  id <MTLDevice> device = MTLCreateSystemDefaultDevice();
  id<MTLCommandQueue> commandQueue = [device newCommandQueue];
  MTLCompileOptions *options = [[MTLCompileOptions alloc] init];
  NSError *error;
  id<MTLLibrary> lib1 = [device newLibraryWithSource:@"\
    #include <metal_stdlib>\n\
    using namespace metal;\n\
    kernel void readLevelFrom1(texture2d<float, access::read> input [[texture(0)]], \n\
                               texture1d<float, access::write> output [[texture(1)]]) { \n\
      float4 pixel = input.read(uint2(0,0),1); \n\
      output.write(pixel.r, 0); \n\
      output.write(pixel.g, 1); \n\
      output.write(pixel.b, 2); \n\
      output.write(pixel.a, 3); \n\
  }"
                                             options:options error:&error];
  if (error) {
    NSLog(@"Error: %@", error.localizedDescription);
    exit(1);
  }
  id<MTLLibrary> lib2 = [device newLibraryWithSource:@"\
    #include <metal_stdlib>\n\
    using namespace metal;\n\
    kernel void readLevelFrom1(texture2d<float, access::read> input [[texture(0)]], \n\
                               texture1d<float, access::write> output [[texture(1)]]) { \n\
      float4 pixel = input.read(uint2(0,0),1); \n\
      output.write(pixel.r, 0); \n\
      output.write(pixel.g, 1); \n\
      output.write(pixel.b, 2); \n\
      output.write(pixel.a, 3); \n\
    } \n\
    kernel void dummy(){}"
                                             options:options error:&error];
  if (error) {
    NSLog(@"Error: %@", error.localizedDescription);
    exit(1);
  }

  // Create a texture
  MTLTextureDescriptor *createDescriptor =
      [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                         width:8
                                                        height:8
                                                     mipmapped:YES];
  id<MTLTexture> texture = [device newTextureWithDescriptor:createDescriptor];
  
  // Fill the texture with data
  MTLRegion textureRegion = MTLRegionMake2D(0, 0, texture.width, texture.height);
  unsigned char* myData = malloc(4 * 8 * 8);
  for (int i = 0; i < texture.width * texture.height * 4; i++) {
    myData[i] = i;
  }
  [texture replaceRegion:textureRegion mipmapLevel:0 withBytes:myData bytesPerRow:texture.width*4];
  
  // Build a pyramid
  id<MTLCommandBuffer> createCommandBuffer = [commandQueue commandBuffer];
  id<MTLBlitCommandEncoder> blitEncoder = [createCommandBuffer blitCommandEncoder];
  [blitEncoder generateMipmapsForTexture:texture];
  [blitEncoder endEncoding];
  [createCommandBuffer commit];
  [createCommandBuffer waitUntilCompleted];
  
  // Verify the content in level 0 and level 1
  MTLRegion region = MTLRegionMake2D(0, 0, 1, 1);
  unsigned char data0[4];
  [texture getBytes:data0 bytesPerRow:4 fromRegion:region mipmapLevel:0];
  NSLog(@"Level 0 values for (0, 0): %d, %d, %d", (int)data0[1], (int)data0[2], (int)data0[3]);
  
  unsigned char data1[4];
  [texture getBytes:data1 bytesPerRow:4 fromRegion:region mipmapLevel:1];
  NSLog(@"Level 1 values for (0, 0): %d, %d, %d", (int)data1[1], (int)data1[2], (int)data1[3]);
  
  // Run the two readFromLevel1 shaders.
  for (int i = 0; i < 2; i++) {
    // In the first iteration select the commented dummy function and in the second the other.
    id<MTLFunction> kernelFunction;
    if (i == 0) {
      kernelFunction = [lib1 newFunctionWithName:@"readLevelFrom1"];
    }
    else {
      kernelFunction = [lib2 newFunctionWithName:@"readLevelFrom1"];
    }
    NSError *error = nil;
    id<MTLComputePipelineState> pipeline = [device newComputePipelineStateWithFunction:kernelFunction error:&error];
    id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
    id<MTLComputeCommandEncoder> commandEncoder = [commandBuffer computeCommandEncoder];
    
    // Create the output texture
    MTLTextureDescriptor *descriptor = [[MTLTextureDescriptor alloc] init];
    descriptor.textureType = MTLTextureType1D;
    descriptor.pixelFormat = MTLPixelFormatR32Float;
    descriptor.width = 4;
    id<MTLTexture> output = [device newTextureWithDescriptor:descriptor];
    
    // Run the function
    MTLSize threadgroupCounts = MTLSizeMake(1, 1, 1);
    MTLSize threadgroups = MTLSizeMake(1, 1, 1);
    [commandEncoder setComputePipelineState:pipeline];
    [commandEncoder setTexture:texture atIndex:0];
    [commandEncoder setTexture:output atIndex:1];
    [commandEncoder dispatchThreadgroups:threadgroups threadsPerThreadgroup:threadgroupCounts];
    [commandEncoder endEncoding];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
    
    // Print the metal output (should be similar to level1 data).
    float res[4];
    [output getBytes:&res bytesPerRow:16 fromRegion:MTLRegionMake1D(0,4) mipmapLevel:0];
    NSLog(@"Iteration %d, Read level 1 from metal. Values for (0,0): %d, %d, %d", i, (int)(res[1]*255), (int)(res[2]*255), (int)(res[3]*255));
  }
}

@end
