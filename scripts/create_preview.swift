import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers
let root = URL(fileURLWithPath:CommandLine.arguments[1])
let ctx = CGContext(data:nil,width:1240,height:760,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.setFillColor(CGColor(red:0.95,green:0.97,blue:0.98,alpha:1));ctx.fill(CGRect(x:0,y:0,width:1240,height:760))
func text(_ s:String,_ x:Double,_ y:Double,_ size:CGFloat) {
 let attrs:[NSAttributedString.Key:Any] = [NSAttributedString.Key(kCTFontAttributeName as String):CTFontCreateWithName("PingFangSC-Semibold" as CFString,size,nil), NSAttributedString.Key(kCTForegroundColorAttributeName as String):CGColor(gray:0.2,alpha:1)]
 let line=CTLineCreateWithAttributedString(NSAttributedString(string:s,attributes:attrs))
 ctx.textPosition=CGPoint(x:x,y:y);CTLineDraw(line,ctx)
}
text("法语动词变位 · iOS",43,714,25)
let labels=["首页 · 每日目标","动词单 · 分组选择","练习 · 六人称输入","纠错 · 重试与下一题"]
let names=["01-home.png","02-verb-list.png","05-practice-keyboard.png","10-perdre-feedback.png"]
for i in 0..<4 {
 let x=Double(43+i*294)
 let rect=CGRect(x:x,y:80,width:272,height:592)
 ctx.setFillColor(CGColor(gray:0.83,alpha:1));ctx.fill(rect.insetBy(dx:-1,dy:-1))
 if let src=CGImageSourceCreateWithURL(root.appendingPathComponent("screenshots/"+names[i]) as CFURL,nil),let image=CGImageSourceCreateImageAtIndex(src,0,nil) {ctx.draw(image,in:rect)}
 text(labels[i],x,45,17)
}
let destination=CGImageDestinationCreateWithURL(root.appendingPathComponent("preview.png") as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(destination,ctx.makeImage()!,nil)
assert(CGImageDestinationFinalize(destination))
