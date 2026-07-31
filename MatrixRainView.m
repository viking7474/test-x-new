#import "MatrixRainView.h"
#import "WeaponXTheme.h"

@interface MatrixRainCharacter : NSObject
@property (nonatomic, assign) CGPoint position;
@property (nonatomic, copy) NSString *character;
@property (nonatomic, strong) UIColor *color;
@property (nonatomic, assign) CGFloat speed;
@property (nonatomic, assign) CGFloat opacity;


@end

@implementation MatrixRainCharacter

- (instancetype)init {
    if (self = [super init]) {
        // Set default properties
        _character = [self randomCharacter];
        _speed = (arc4random_uniform(10) + 1) / 10.0; // 0.1 to 1.0
        _opacity = 1.0;
    }
    return self;
}

- (NSString *)randomCharacter {
    // Include Japanese katakana, hiragana, and other symbols for more futuristic look
    NSArray *characterSets = @[
        @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789$#@&%!?;:=+*-/\\",
        @"ｦｧｨｩｪｫｬｭｮｯｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ",
        @"αβγδεζηθικλμνξοπρστυφχψω",
        @"∂∆∏∑−±∞≠≈∫√∞²³°≤≥→×÷⌂⌐¬"
    ];
    
    // Select a random character set with higher probability for Japanese characters
    int setIndex = arc4random_uniform(100) < 75 ? arc4random_uniform(3) + 1 : 0;
    NSString *selectedSet = characterSets[setIndex];
    
    int randomIndex = arc4random_uniform((u_int32_t)[selectedSet length]);
    return [selectedSet substringWithRange:NSMakeRange(randomIndex, 1)];
}



@end

@interface MatrixRainView ()
@property (nonatomic, strong) NSMutableArray *columns;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) UIColor *matrixColor;
@property (nonatomic, strong) NSArray *depthColors;


@end

@implementation MatrixRainView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setup];
    }
    return self;
}

- (void)setup {
    self.backgroundColor = [UIColor clearColor];
    self.matrixColor = [UIColor systemGreenColor];
    
    // Define colors for depth effect - only green shades, no white
    self.depthColors = @[
        [UIColor colorWithRed:0.1 green:1.0 blue:0.1 alpha:1.0],     // Bright green
        [UIColor colorWithRed:0.0 green:0.8 blue:0.0 alpha:1.0],     // Medium green
        [UIColor systemGreenColor],                                   // Standard green
        [UIColor colorWithRed:0.0 green:0.5 blue:0.0 alpha:1.0]      // Dark green
    ];
    
    self.columns = [NSMutableArray array];
    
    // Set up columns of characters - wider columns for less density
    CGFloat columnWidth = 25.0; // Increased from 15.0 to reduce density
    NSInteger numColumns = self.bounds.size.width / columnWidth;
    
    for (int i = 0; i < numColumns; i++) {
        // Randomly skip some columns (30% chance)
        if (arc4random_uniform(100) < 30) {
            [self.columns addObject:[NSMutableArray array]]; // Empty column
            continue;
        }
        
        NSMutableArray *column = [NSMutableArray array];
        
        // Random starting position with more spacing
        CGFloat startY = - (CGFloat)(arc4random_uniform(1000));
        
        // Fewer characters per column (3-12 instead of 5-20)
        int numChars = arc4random_uniform(10) + 3;
        
        for (int j = 0; j < numChars; j++) {
            MatrixRainCharacter *character = [[MatrixRainCharacter alloc] init];
            // More vertical spacing between characters
            character.position = CGPointMake(i * columnWidth, startY - (j * 25));
            
            // Assign depth-based color
            int depthIndex = arc4random_uniform(4);
            character.color = self.depthColors[depthIndex];
            
            // Vary speed based on depth
            character.speed = (0.3 + (arc4random_uniform(12) / 10.0)) * (1.0 - (depthIndex * 0.15));
            
            [column addObject:character];
        }
        
        [self.columns addObject:column];
    }
}

- (void)startAnimation {
    // Respect Accessibility > Reduce Motion: skip the animated matrix rain.
    if (WXReduceMotionEnabled()) {
        [self stopAnimation];
        return;
    }
    if (!self.displayLink) {
        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateMatrix)];
        // Use an even lower frame rate (20 fps) to reduce CPU usage further
        self.displayLink.preferredFramesPerSecond = 20;
        [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    }
}

- (void)stopAnimation {
    [self.displayLink invalidate];
    self.displayLink = nil;
    [self setNeedsDisplay];
}

- (void)updateWithColor:(UIColor *)color {
    self.matrixColor = color;
    for (NSMutableArray *column in self.columns) {
        for (MatrixRainCharacter *character in column) {
            character.color = color;
        }
    }
    [self setNeedsDisplay];
}

- (void)updateMatrix {
    static int frameCount = 0;
    frameCount++;
    
    for (NSMutableArray *column in self.columns) {
        // Skip empty columns
        if (column.count == 0) {
            continue;
        }
        
        // Track the first visible character to make it brighter
        MatrixRainCharacter *leadCharacter = nil;
        CGFloat minY = CGFLOAT_MAX;
        
        for (MatrixRainCharacter *character in column) {
            // Move character down with its own speed
            CGPoint position = character.position;
            position.y += character.speed * 6; // Reduced speed multiplier from 8 to 6
            character.position = position;
            
            // Track lead character (first visible in column)
            if (position.y > 0 && position.y < minY) {
                minY = position.y;
                leadCharacter = character;
            }
            
            // Random character change (reduced from 10% to 5% chance)
            if (arc4random_uniform(100) < 5) {
                character.character = [character randomCharacter];
            }
            
            // If character moves off-screen, reset to top
            if (position.y > self.bounds.size.height) {
                position.y = -15;
                character.position = position;
                character.opacity = 1.0;
                character.character = [character randomCharacter];
                
                // Occasionally change depth/color when recycling (reduced from 30% to 20%)
                if (arc4random_uniform(100) < 20) {
                    int depthIndex = arc4random_uniform(4);
                    character.color = self.depthColors[depthIndex];
                    character.speed = (0.3 + (arc4random_uniform(12) / 10.0)) * (1.0 - (depthIndex * 0.15));
                }
            }
            
            // Fade out as it falls
            if (position.y > self.bounds.size.height - 150) {
                character.opacity = (self.bounds.size.height - position.y) / 150.0;
            }
        }
        
        // Highlight lead character with a brighter green (not white) and full opacity
        if (leadCharacter && arc4random_uniform(100) < 30) {
            leadCharacter.color = [UIColor colorWithRed:0.0 green:1.0 blue:0.0 alpha:1.0]; // Pure green, not white-ish
            leadCharacter.opacity = 1.0;
        }
    }
    
    // Change random characters less frequently (every 45 frames instead of 30)
    if (frameCount % 45 == 0) {
        int numChanges = 5 + arc4random_uniform(10); // Reduced from 10-30 to 5-15
        for (int i = 0; i < numChanges; i++) {
            int colIndex = arc4random_uniform((uint32_t)self.columns.count);
            NSMutableArray *column = self.columns[colIndex];
            
            if (column.count > 0) {
                int charIndex = arc4random_uniform((uint32_t)column.count);
                MatrixRainCharacter *character = column[charIndex];
                character.character = [character randomCharacter];
            }
        }
    }
    
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextClearRect(context, rect);
    
    for (NSMutableArray *column in self.columns) {
        for (MatrixRainCharacter *character in column) {
            // Skip if outside the visible area
            if (character.position.y < -20 || character.position.y > self.bounds.size.height + 20) {
                continue;
            }
            
            // Set the alpha for the character
            CGContextSetAlpha(context, character.opacity);
            
            // Set the color
            UIColor *drawColor = character.color;
            CGContextSetFillColorWithColor(context, drawColor.CGColor);
            
            // Draw the character
            [character.character drawAtPoint:character.position 
                            withAttributes:@{
                                NSFontAttributeName: [UIFont systemFontOfSize:14.0],
                                NSForegroundColorAttributeName: drawColor
                            }];
            
            // Enhanced green glow effect for ALL characters (not just some)
            if (arc4random_uniform(100) < 40) { // Increased chance of glow from 8% to 40%
                CGContextSaveGState(context);
                
                // Create a stronger green glow effect
                CGFloat glowIntensity = (arc4random_uniform(40) / 100.0) + 0.2; // 0.2-0.6 intensity
                UIColor *glowColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.0 alpha:glowIntensity];
                
                // Draw multiple glow layers
                for (int i = 1; i <= 3; i++) {
                    CGFloat offset = i * 0.5;
                    CGFloat alpha = character.opacity * (0.5 / i);
                    
                    CGContextSetAlpha(context, alpha);
                    [character.character drawAtPoint:CGPointMake(character.position.x + offset, character.position.y)
                                     withAttributes:@{
                                         NSFontAttributeName: [UIFont systemFontOfSize:14.0],
                                         NSForegroundColorAttributeName: glowColor
                                     }];
                    
                    [character.character drawAtPoint:CGPointMake(character.position.x - offset, character.position.y)
                                     withAttributes:@{
                                         NSFontAttributeName: [UIFont systemFontOfSize:14.0],
                                         NSForegroundColorAttributeName: glowColor
                                     }];
                    
                    [character.character drawAtPoint:CGPointMake(character.position.x, character.position.y + offset)
                                     withAttributes:@{
                                         NSFontAttributeName: [UIFont systemFontOfSize:14.0],
                                         NSForegroundColorAttributeName: glowColor
                                     }];
                    
                    [character.character drawAtPoint:CGPointMake(character.position.x, character.position.y - offset)
                                     withAttributes:@{
                                         NSFontAttributeName: [UIFont systemFontOfSize:14.0],
                                         NSForegroundColorAttributeName: glowColor
                                     }];
                }
                
                CGContextRestoreGState(context);
            }
        }
    }
}



@end
