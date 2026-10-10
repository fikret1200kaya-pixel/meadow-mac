import AVFoundation

// Offline capture advances the actual production renderer at exactly 30 fps.
// The production application is unchanged; only the copied capture app gets a virtual clock.
final class PromoCapture {
 let owner:AppDelegate
 let output=URL(fileURLWithPath:FileManager.default.currentDirectoryPath+"/promo-capture")
 let cases=[("meadow","day"),("snow","day"),("lake","day"),("wheat","golden"),("sakura","day"),("sakura","golden"),("sakura","night")]
 var index=0,frames=0,warmup=0
 var writer:AVAssetWriter?,input:AVAssetWriterInput?,adaptor:AVAssetWriterInputPixelBufferAdaptor?
 init(_ owner:AppDelegate){self.owner=owner}
 func begin(){
  try! FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
  owner.cursorTimer?.invalidate();owner.quality="ultra";owner.fps=60;owner.reload();owner.togglePreview()
  owner.surfaces.first!.window.setContentSize(NSSize(width:3840,height:2160))
  owner.surfaces.first!.web.setFrameSize(NSSize(width:3840,height:2160))
  DispatchQueue.main.asyncAfter(deadline:.now()+5){self.next()}
 }
 func next(){
  if index==cases.count{owner.quit();return}
  let c=cases[index],s=owner.surfaces.first!
  s.run("window.meadowMac.scene('\(c.0)');window.meadowMac.mode('\(c.1)');window.meadowMac.preview(false);document.querySelectorAll('body > div').forEach(e=>e.style.setProperty('display','none','important'))")
  warmup=0
  DispatchQueue.main.asyncAfter(deadline:.now()+3){self.warm()}
 }
 func warm(){
  owner.surfaces.first!.web.evaluateJavaScript("window.__promoStep(1000/30)"){value,error in
   if let error=error{print(error);exit(1)}
   self.warmup+=1
   if self.warmup<60{DispatchQueue.main.async{self.warm()}}
   else{
    let state=value as? [String:Any] ?? [:]
    print("4K renderer state: \(state)");fflush(stdout)
    guard (state["width"] as? Int ?? 0)>=3840,(state["height"] as? Int ?? 0)>=2160 else{exit(1)}
    self.record()
   }
  }
 }
 func record(){
  writer=try! AVAssetWriter(outputURL:output.appendingPathComponent("\(index)-\(cases[index].0)-\(cases[index].1).mp4"),fileType:.mp4)
  input=AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:3840,AVVideoHeightKey:2160,AVVideoCompressionPropertiesKey:[AVVideoAverageBitRateKey:40000000,AVVideoExpectedSourceFrameRateKey:30,AVVideoMaxKeyFrameIntervalKey:30]])
  input!.expectsMediaDataInRealTime=false
  adaptor=AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input!,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32ARGB,kCVPixelBufferWidthKey as String:3840,kCVPixelBufferHeightKey as String:2160,kCVPixelBufferCGImageCompatibilityKey as String:true,kCVPixelBufferCGBitmapContextCompatibilityKey as String:true])
  writer!.add(input!);writer!.startWriting();writer!.startSession(atSourceTime:.zero);frames=0;tick()
 }
 func tick(){
  if frames>=150{
   input!.markAsFinished();writer!.finishWriting{DispatchQueue.main.async{
    print("Captured 4K \(self.cases[self.index]): \(self.frames) frames, status \(self.writer!.status.rawValue)");fflush(stdout)
    guard self.writer!.status == .completed else{exit(1)}
    self.index+=1;self.next()
   }};return
  }
  guard input!.isReadyForMoreMediaData else{DispatchQueue.main.asyncAfter(deadline:.now()+0.02){self.tick()};return}
  let s=owner.surfaces.first!,time=Double(frames)/30
  s.web.evaluateJavaScript("window.meadowMac.cursor(\(0.5+0.3*sin(time*1.7)),\(0.68+0.15*cos(time*1.4)));window.__promoStep(1000/30)"){_,error in
   if let error=error{print(error);exit(1)}
   let config=WKSnapshotConfiguration();config.rect=s.web.bounds;config.snapshotWidth=3840;config.afterScreenUpdates=true
   s.web.takeSnapshot(with:config){image,error in
    guard let image=image,let cg=image.cgImage(forProposedRect:nil,context:nil,hints:nil),let pool=self.adaptor!.pixelBufferPool else{print(error as Any);exit(1)}
    var buffer:CVPixelBuffer?;CVPixelBufferPoolCreatePixelBuffer(nil,pool,&buffer)
    guard let b=buffer else{exit(1)}
    CVPixelBufferLockBaseAddress(b,[])
    let ctx=CGContext(data:CVPixelBufferGetBaseAddress(b),width:3840,height:2160,bitsPerComponent:8,bytesPerRow:CVPixelBufferGetBytesPerRow(b),space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipFirst.rawValue)!
    ctx.draw(cg,in:CGRect(x:0,y:0,width:3840,height:2160));CVPixelBufferUnlockBaseAddress(b,[])
    guard self.adaptor!.append(b,withPresentationTime:CMTime(value:Int64(self.frames),timescale:30)) else{print(self.writer!.error as Any);exit(1)}
    self.frames+=1
    DispatchQueue.main.async{self.tick()}
   }
  }
 }
}
let app=NSApplication.shared
let delegate=AppDelegate();app.delegate=delegate
let capture=PromoCapture(delegate)
DispatchQueue.main.asyncAfter(deadline:.now()+8){capture.begin()}
app.run()
