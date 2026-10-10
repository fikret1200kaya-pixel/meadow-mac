import AVFoundation

final class PromoCapture {
 let owner: AppDelegate
 let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath+"/promo-capture")
 let cases = [("meadow","day"),("snow","day"),("lake","day"),("wheat","golden"),("sakura","day"),("sakura","golden"),("sakura","night")]
 var index=0, busy=false, frames=0
 var start=Date(), timer:Timer?, writer:AVAssetWriter?, input:AVAssetWriterInput?, adaptor:AVAssetWriterInputPixelBufferAdaptor?
 init(_ owner:AppDelegate){self.owner=owner}
 func begin(){
  try! FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
  owner.togglePreview()
  owner.surfaces.first!.window.setContentSize(NSSize(width:1280,height:800))
  next()
 }
 func next(){
  if index==cases.count {owner.quit();return}
  let s=owner.surfaces.first!, c=cases[index]
  s.run("window.meadowMac.scene('\(c.0)');window.meadowMac.mode('\(c.1)');window.meadowMac.preview(false);document.querySelectorAll('body > div').forEach(e=>e.style.setProperty('display','none','important'))")
  DispatchQueue.main.asyncAfter(deadline:.now()+3){self.record()}
 }
 func record(){
  let url=output.appendingPathComponent("\(index)-\(cases[index].0)-\(cases[index].1).mp4")
  writer=try! AVAssetWriter(outputURL:url,fileType:.mp4)
  input=AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:1280,AVVideoHeightKey:800,AVVideoCompressionPropertiesKey:[AVVideoAverageBitRateKey:8000000]])
  input!.expectsMediaDataInRealTime=true
  adaptor=AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input!,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32ARGB,kCVPixelBufferWidthKey as String:1280,kCVPixelBufferHeightKey as String:800,kCVPixelBufferCGImageCompatibilityKey as String:true,kCVPixelBufferCGBitmapContextCompatibilityKey as String:true])
  writer!.add(input!);writer!.startWriting();writer!.startSession(atSourceTime:.zero)
  start=Date();frames=0
  timer=Timer.scheduledTimer(withTimeInterval:1.0/15,repeats:true){_ in self.tick()}
 }
 func tick(){
  guard !busy else{return}
  let time=Date().timeIntervalSince(start)
  if time>=5.5 {
   timer?.invalidate();input!.markAsFinished();busy=true
   writer!.finishWriting {DispatchQueue.main.async{
    print("Captured \(self.cases[self.index]) \(self.frames) frames: \(self.writer!.status.rawValue)");fflush(stdout)
    if self.writer!.status != .completed || self.frames<15 {exit(1)}
    self.index+=1;self.busy=false;self.next()
   }};return
  }
  guard input!.isReadyForMoreMediaData else{return}
  busy=true
  let s=owner.surfaces.first!
  s.run("window.meadowMac.cursor(\(0.5+0.3*sin(time*1.7)),\(0.68+0.15*cos(time*1.4)))")
  let config=WKSnapshotConfiguration();config.rect=s.web.bounds;config.snapshotWidth=1280
  s.web.takeSnapshot(with:config){image,error in
   defer{self.busy=false}
   guard let image=image,let cg=image.cgImage(forProposedRect:nil,context:nil,hints:nil),let pool=self.adaptor!.pixelBufferPool else{return}
   var buffer:CVPixelBuffer?;CVPixelBufferPoolCreatePixelBuffer(nil,pool,&buffer)
   guard let b=buffer else{return}
   CVPixelBufferLockBaseAddress(b,[])
   let ctx=CGContext(data:CVPixelBufferGetBaseAddress(b),width:1280,height:800,bitsPerComponent:8,bytesPerRow:CVPixelBufferGetBytesPerRow(b),space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipFirst.rawValue)!
   ctx.draw(cg,in:CGRect(x:0,y:0,width:1280,height:800));CVPixelBufferUnlockBaseAddress(b,[])
   if self.adaptor!.append(b,withPresentationTime:CMTime(seconds:time,preferredTimescale:600)){self.frames+=1}
  }
 }
}
let app=NSApplication.shared
let delegate=AppDelegate();app.delegate=delegate
let capture=PromoCapture(delegate)
DispatchQueue.main.asyncAfter(deadline:.now()+8){capture.begin()}
app.run()
