import 'dart:math' as math;
import 'package:flutter/material.dart';

class PulsarPalette {
  const PulsarPalette(this.light, this.mid, this.deep);
  final Color light, mid, deep;
  static const values = [
    PulsarPalette(Color(0xFFBDECF1),Color(0xFF5D9EB1),Color(0xFF536A98)),
    PulsarPalette(Color(0xFFD0C7EF),Color(0xFF8174A8),Color(0xFF555B82)),
    PulsarPalette(Color(0xFFC5DFEF),Color(0xFF6E94B8),Color(0xFF5A608C)),
    PulsarPalette(Color(0xFFE4C4D4),Color(0xFF9B718B),Color(0xFF6D6388)),
    PulsarPalette(Color(0xFFE9D6B5),Color(0xFFA98A66),Color(0xFF766777)),
    PulsarPalette(Color(0xFFD3D9E0),Color(0xFF818B99),Color(0xFF555E70)),
    PulsarPalette(Color(0xFFC2E3D7),Color(0xFF73A794),Color(0xFF597183)),
  ];
}

class LiquidOrb extends StatefulWidget {
  const LiquidOrb({
    required this.size, required this.palette, required this.value, required this.total,
    super.key, this.onTap, this.showValue = true, this.complete = false, this.armed = false,
    this.hero = false, this.entryDelay = Duration.zero,
  });
  final double size;
  final PulsarPalette palette;
  final int value, total;
  final VoidCallback? onTap;
  final bool showValue, complete, armed, hero;
  final Duration entryDelay;
  @override State<LiquidOrb> createState() => _LiquidOrbState();
}

class _LiquidOrbState extends State<LiquidOrb> with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _entryController;
  late final Animation<double> _entry;
  @override void initState() {
    super.initState();
    _controller = AnimationController(vsync:this,duration:const Duration(seconds:12))..repeat();
    _entryController = AnimationController(vsync:this,duration:const Duration(milliseconds:700));
    _entry = CurvedAnimation(parent:_entryController,curve:Curves.easeOutBack);
    if(widget.entryDelay == Duration.zero) {
      _entryController.forward();
    } else {
      Future<void>.delayed(widget.entryDelay,(){ if(mounted) _entryController.forward(); });
    }
  }
  @override void dispose(){ _controller.dispose(); _entryController.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final progress = widget.total <= 0 ? 0.0 : (widget.value/widget.total).clamp(0.0,1.0);
    return Semantics(
      button: widget.onTap != null,
      label: '${widget.value} / ${widget.total}',
      child: GestureDetector(
        behavior:HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: ScaleTransition(
          scale:_entry,
          child:SizedBox.square(
            dimension:widget.size,
            child:AnimatedBuilder(
              animation:_controller,
              builder:(context,_)=>Stack(alignment:Alignment.center,children:[
                RepaintBoundary(child:CustomPaint(size:Size.square(widget.size),painter:LiquidOrbPainter(
                  phase:_controller.value,palette:widget.palette,progress:progress,complete:widget.complete,hero:widget.hero))),
                if(widget.showValue) AnimatedSwitcher(
                  duration:const Duration(milliseconds:250),
                  child:widget.armed
                    ? const Text('1/2',key:ValueKey('armed'),style:TextStyle(fontSize:12,fontWeight:FontWeight.w700,color:Color(0xFFD8C8BA)))
                    : widget.complete
                      ? Icon(Icons.check_rounded,key:const ValueKey('done'),size:widget.size*.17,color:const Color(0xFFEAF3F5))
                      : RichText(key:ValueKey(widget.value),text:TextSpan(children:[
                          TextSpan(text:'${widget.value}',style:TextStyle(fontSize:widget.size*.16,fontWeight:FontWeight.w600,color:const Color(0xFFF0F4F6),letterSpacing:-1)),
                          TextSpan(text:'/${widget.total}',style:TextStyle(fontSize:widget.size*.065,color:const Color(0xFF788696))),
                        ])),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class LiquidOrbPainter extends CustomPainter {
  LiquidOrbPainter({required this.phase,required this.palette,required this.progress,required this.complete,required this.hero});
  final double phase,progress;
  final PulsarPalette palette;
  final bool complete,hero;
  @override void paint(Canvas canvas, Size size) {
    final c=Offset(size.width/2,size.height/2), r=size.width*(hero ? .30 : .285), a=phase*math.pi*2;
    final aura=Paint()..shader=RadialGradient(colors:[palette.light.withValues(alpha:complete ? .16 : .08),palette.mid.withValues(alpha:.035),Colors.transparent],stops:const[0,.52,1]).createShader(Rect.fromCircle(center:c,radius:r*1.85));
    canvas.drawCircle(c,r*1.85,aura);
    _orbit(canvas,c,r,a,-.22,r*1.7,r*.72,palette.light.withValues(alpha:.18),2);
    _orbit(canvas,c,r,-a*.61,.94,r*1.26,r*1.02,palette.deep.withValues(alpha:.10),1);
    canvas.save(); canvas.clipPath(Path()..addOval(Rect.fromCircle(center:c,radius:r)));
    canvas.drawCircle(c,r,Paint()..shader=RadialGradient(center:const Alignment(-.36,-.34),radius:1.05,colors:[palette.light.withValues(alpha:.22),const Color(0xFF14202C),const Color(0xFF091019),const Color(0xFF020407)],stops:const[0,.22,.64,1]).createShader(Rect.fromCircle(center:c,radius:r)));
    canvas.saveLayer(Rect.fromCircle(center:c,radius:r),Paint()..blendMode=BlendMode.screen);
    final blobData=[
      (Offset(math.sin(a*.78)*r*.38,math.cos(a*.59)*r*.26),r*.92,palette.light,.26),
      (Offset(math.cos(a*.46+1.8)*r*.48,math.sin(a*.65+1.1)*r*.34),r*.82,palette.deep,.21),
      (Offset(math.sin(a*.37+3.2)*r*.52,math.cos(a*.73+2.4)*r*.38),r*.7,palette.mid,.18),
    ];
    for(final b in blobData){ final p=c+b.$1; canvas.drawCircle(p,b.$2,Paint()..shader=RadialGradient(colors:[b.$3.withValues(alpha:b.$4),b.$3.withValues(alpha:b.$4*.55),Colors.transparent],stops:const[0,.42,1]).createShader(Rect.fromCircle(center:p,radius:b.$2))..maskFilter=MaskFilter.blur(BlurStyle.normal,r*.08)); }
    for(var i=0;i<3;i++){
      final y=c.dy-r*.38+i*r*.36+math.sin(a*.7+i)*r*.13;
      final path=Path()..moveTo(c.dx-r*1.25,y)..cubicTo(c.dx-r*.5,y-math.sin(a*.42+i)*r*.42,c.dx+r*.38,y+math.cos(a*.36+i)*r*.38,c.dx+r*1.25,y-r*.08);
      canvas.drawPath(path,Paint()..style=PaintingStyle.stroke..strokeWidth=r*(.18-i*.025)..strokeCap=StrokeCap.round..shader=LinearGradient(colors:[Colors.transparent,(i.isEven?palette.light:palette.deep).withValues(alpha:.12+i*.035),(i.isEven?palette.mid:palette.light).withValues(alpha:.27-i*.035),Colors.transparent]).createShader(Rect.fromCircle(center:c,radius:r))..maskFilter=MaskFilter.blur(BlurStyle.normal,r*.035));
    }
    canvas.restore();
    canvas.drawCircle(c,r,Paint()..shader=RadialGradient(center:const Alignment(-.35,-.4),radius:1.05,colors:[Colors.white.withValues(alpha:.13),Colors.transparent,Colors.black.withValues(alpha:.62)],stops:const[0,.35,1]).createShader(Rect.fromCircle(center:c,radius:r)));
    canvas.restore();
    canvas.drawCircle(c,r,Paint()..style=PaintingStyle.stroke..strokeWidth=.8..shader=LinearGradient(colors:[palette.light.withValues(alpha:.62),Colors.white.withValues(alpha:.07),palette.deep.withValues(alpha:.18)]).createShader(Rect.fromCircle(center:c,radius:r)));
    canvas.drawArc(Rect.fromCircle(center:c,radius:r*.8),math.pi*1.18,math.pi*.34,false,Paint()..style=PaintingStyle.stroke..strokeWidth=.7..color=Colors.white.withValues(alpha:.23));
    canvas.drawArc(Rect.fromCircle(center:c,radius:r*1.16),-math.pi/2,math.pi*2*progress,false,Paint()..style=PaintingStyle.stroke..strokeWidth=1.05..strokeCap=StrokeCap.round..color=palette.light.withValues(alpha:complete ? .82 : .57));
  }
  void _orbit(Canvas canvas,Offset c,double r,double motion,double tilt,double w,double h,Color color,int dots){
    canvas.save();canvas.translate(c.dx,c.dy);canvas.rotate(tilt+motion*.08);canvas.drawOval(Rect.fromCenter(center:Offset.zero,width:w,height:h),Paint()..style=PaintingStyle.stroke..strokeWidth=.65..color=color);
    for(var i=0;i<dots;i++){final q=motion+i*math.pi;final p=Offset(math.cos(q)*w/2,math.sin(q)*h/2);canvas.drawCircle(p,i==0?1.5:1.0,Paint()..color=(i==0?palette.light:palette.deep)..maskFilter=const MaskFilter.blur(BlurStyle.normal,2));}
    canvas.restore();
  }
  @override bool shouldRepaint(covariant LiquidOrbPainter old)=>phase!=old.phase||progress!=old.progress||complete!=old.complete||palette!=old.palette;
}
