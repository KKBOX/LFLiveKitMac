#import "LFGPUImageEmptyFilter.h"

NSString *const kGPUImageInvertFragmentShaderString = SHADER_STRING
(varying
	vec2 textureCoordinate;

	uniform
	sampler2D inputImageTexture;

	void main() {
		vec4 textureColor = texture2D(inputImageTexture, textureCoordinate);
		gl_FragColor = vec4((textureColor.rgb), textureColor.w);
	}
);

@implementation LFGPUImageEmptyFilter

- (id)init;
{
	if (!(self = [super initWithFragmentShaderFromString:kGPUImageInvertFragmentShaderString])) {
		return nil;
	}

	return self;
}

@end
