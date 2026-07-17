import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/workout.dart';
import 'services/storage.dart';
import 'widgets/liquid_orb.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor:Colors.transparent,statusBarIconBrightness:Brightness.light,systemNavigationBarColor:Color(0xFF070A11)));
  runApp(const PulsarApp());
}

class PulsarApp extends StatefulWidget { const PulsarApp({super.key}); @override State<PulsarApp> createState()=>_PulsarAppState(); }
class _PulsarAppState extends State<PulsarApp> {
  late final PulsarController controller;
  @override void initState(){super.initState();controller=PulsarController()..initialize();}
  @override Widget build(BuildContext context)=>MaterialApp(
    debugShowCheckedModeBanner:false,title:'Pulsar',theme:ThemeData(useMaterial3:true,brightness:Brightness.dark,scaffoldBackgroundColor:Colors.transparent,fontFamily:'sans-serif',colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xFF8FCFD9),brightness:Brightness.dark),textTheme:const TextTheme(bodyMedium:TextStyle(color:Color(0xFFC3CDD6)),bodySmall:TextStyle(color:Color(0xFF758294)))),
    home:AnimatedBuilder(animation:controller,builder:(context,child)=>controller.ready?PulsarShell(controller:controller):const Scaffold(body:Center(child:CircularProgressIndicator(strokeWidth:1.5)))));
}

class PulsarController extends ChangeNotifier {
  final storage=PulsarStorage();
  bool ready=false;
  List<WorkoutDay> plan=[];
  Map<String,Map<int,int>> completed={};
  Future<void> initialize() async { plan=await storage.loadPlan();completed=await storage.loadSets();ready=true;notifyListeners(); }
  int count(WorkoutDay day,int index)=>completed[day.keyName]?[index]??0;
  int totalSets(WorkoutDay day)=>day.exercises.fold(0,(n,e)=>n+e.sets);
  int doneSets(WorkoutDay day)=>day.exercises.asMap().entries.fold(0,(n,e)=>n+count(day,e.key).clamp(0,e.value.sets));
  double progress(WorkoutDay day)=>day.rest?1:totalSets(day)==0?0:doneSets(day)/totalSets(day);
  Future<void> setCount(WorkoutDay day,int index,int value) async {completed.putIfAbsent(day.keyName,()=>{});completed[day.keyName]![index]=value;notifyListeners();await storage.saveSets(completed);}
  Future<void> updatePlan() async {notifyListeners();await storage.savePlan(plan);}
  Future<void> clearRecords() async {completed={};notifyListeners();await storage.saveSets(completed);}
}

class PulsarShell extends StatefulWidget { const PulsarShell({required this.controller,super.key}); final PulsarController controller; @override State<PulsarShell> createState()=>_PulsarShellState(); }
class _PulsarShellState extends State<PulsarShell> {
  int index=0;
  @override Widget build(BuildContext context){final pages=[GalaxyScreen(controller:widget.controller),RecordsScreen(controller:widget.controller),SettingsScreen(controller:widget.controller)];return Scaffold(
    body:PulsarBackdrop(child:SafeArea(bottom:false,child:IndexedStack(index:index,children:pages))),
    bottomNavigationBar:NavigationBar(height:68,backgroundColor:const Color(0xEE080C14),indicatorColor:const Color(0x1A9BCBD4),selectedIndex:index,onDestinationSelected:(v){HapticFeedback.selectionClick();setState(()=>index=v);},destinations:const[
      NavigationDestination(icon:Icon(Icons.blur_circular_outlined),selectedIcon:Icon(Icons.blur_circular_rounded),label:'Orbit'),
      NavigationDestination(icon:Icon(Icons.insights_outlined),selectedIcon:Icon(Icons.insights_rounded),label:'Archive'),
      NavigationDestination(icon:Icon(Icons.tune_rounded),selectedIcon:Icon(Icons.tune_rounded),label:'Plan'),
    ]));}
}

class PulsarBackdrop extends StatelessWidget { const PulsarBackdrop({required this.child,super.key}); final Widget child; @override Widget build(BuildContext context)=>DecoratedBox(
  decoration:const BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF070A11),Color(0xFF0A101B),Color(0xFF0C121E)])),
  child:Stack(fit:StackFit.expand,children:[const Positioned(top:-150,right:-140,child:_AmbientGlow(size:340,color:Color(0xFF6670A0))),const Positioned(bottom:-180,left:-170,child:_AmbientGlow(size:380,color:Color(0xFF477B87))),child])); }
class _AmbientGlow extends StatelessWidget { const _AmbientGlow({required this.size,required this.color});final double size;final Color color;@override Widget build(BuildContext context)=>IgnorePointer(child:Container(width:size,height:size,decoration:BoxDecoration(shape:BoxShape.circle,gradient:RadialGradient(colors:[color.withValues(alpha:.11),Colors.transparent]))));}

class PulsarHeader extends StatelessWidget { const PulsarHeader({super.key,this.title,this.progress,this.onBack});final String? title;final double? progress;final VoidCallback? onBack;@override Widget build(BuildContext context)=>SizedBox(height:68,child:Padding(padding:const EdgeInsets.symmetric(horizontal:18),child:Row(children:[
  if(onBack!=null) IconButton(onPressed:onBack,icon:const Icon(Icons.arrow_back_rounded,size:21)) else const _Brand(),
  if(title!=null) Expanded(child:Text(title!,textAlign:TextAlign.center,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700))),
  if(progress!=null) SizedBox(width:82,child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,children:[Text('${(progress!*100).round()}%',style:const TextStyle(fontSize:9,fontWeight:FontWeight.w700,color:Color(0xFFB8C3CC))),const SizedBox(height:6),ClipRRect(borderRadius:BorderRadius.circular(9),child:LinearProgressIndicator(value:progress,minHeight:2,backgroundColor:const Color(0x142A3849),valueColor:const AlwaysStoppedAnimation(Color(0xFF9ACDD5))))]))
  else if(onBack!=null) const SizedBox(width:48) else const Spacer(),
] )));}
class _Brand extends StatelessWidget {const _Brand();@override Widget build(BuildContext context)=>Row(children:[Container(width:34,height:34,decoration:BoxDecoration(borderRadius:BorderRadius.circular(11),border:Border.all(color:const Color(0x667FC0CB))),child:Center(child:Container(width:10,height:10,decoration:const BoxDecoration(shape:BoxShape.circle,gradient:LinearGradient(colors:[Color(0xFFB5E4E9),Color(0xFF7A72AA)]))))),const SizedBox(width:12),const Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[Text('PULSAR',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800,letterSpacing:2.1)),Text('TRAINING CONSTELLATION',style:TextStyle(fontSize:6,color:Color(0xFF667284),letterSpacing:1.4))])]);}

class GalaxyScreen extends StatelessWidget { const GalaxyScreen({required this.controller,super.key});final PulsarController controller;
  @override Widget build(BuildContext context)=>Column(children:[const PulsarHeader(),Expanded(child:LayoutBuilder(builder:(context,box)=>Stack(children:[
    Positioned.fill(child:CustomPaint(painter:GalaxyLinesPainter())),..._nodes(context,box.biggest)
  ])))]);
  List<Widget> _nodes(BuildContext context,Size size){
    const align=[Alignment(-.64,-.78),Alignment(.62,-.82),Alignment(-.78,-.18),Alignment(.69,-.12),Alignment(-.55,.49),Alignment(.61,.45),Alignment(0,.84)];
    const sizes=[112.0,90.0,98.0,120.0,94.0,82.0,88.0];
    return controller.plan.asMap().entries.map((entry){final i=entry.key,day=entry.value,a=align[i],orb=sizes[i];final x=(a.x+1)/2*size.width-orb/2,y=(a.y+1)/2*size.height-orb/2;return Positioned(left:x,top:y,child:Column(mainAxisSize:MainAxisSize.min,children:[
      LiquidOrb(size:orb,palette:PulsarPalette.values[day.palette%PulsarPalette.values.length],value:(controller.progress(day)*100).round(),total:100,complete:controller.progress(day)>=1,onTap:()=>_openDay(context,day)),
      Text(day.day,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w800,letterSpacing:.8)),const SizedBox(height:3),Text(day.title,style:const TextStyle(fontSize:7,color:Color(0xFF657183)))
    ]));}).toList();
  }
  void _openDay(BuildContext context,WorkoutDay day){HapticFeedback.mediumImpact();Navigator.of(context).push(PageRouteBuilder(transitionDuration:const Duration(milliseconds:620),reverseTransitionDuration:const Duration(milliseconds:360),pageBuilder:(context,animation,secondaryAnimation)=>FadeTransition(opacity:animation,child:ScaleTransition(scale:Tween(begin:.92,end:1.0).animate(CurvedAnimation(parent:animation,curve:Curves.easeOutCubic)),child:DayGalaxyScreen(controller:controller,day:day)))));}
}

class GalaxyLinesPainter extends CustomPainter {@override void paint(Canvas canvas,Size size){final paint=Paint()..color=const Color(0x14102031)..style=PaintingStyle.stroke..strokeWidth=.7;final p=Path()..moveTo(size.width*.18,size.height*.12)..cubicTo(size.width*.55,size.height*.03,size.width*.8,size.height*.12,size.width*.82,size.height*.28)..cubicTo(size.width*.84,size.height*.47,size.width*.34,size.height*.42,size.width*.18,size.height*.62)..cubicTo(size.width*.04,size.height*.81,size.width*.61,size.height*.71,size.width*.5,size.height*.94);canvas.drawPath(p,paint);final star=Paint()..color=const Color(0x557EAAB5);for(var i=0;i<20;i++){final x=(i*83%101)/100*size.width,y=(i*47%97)/100*size.height;canvas.drawCircle(Offset(x,y),i%4==0?1.1:.55,star);}}@override bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;}

class DayGalaxyScreen extends StatefulWidget {const DayGalaxyScreen({required this.controller,required this.day,super.key});final PulsarController controller;final WorkoutDay day;@override State<DayGalaxyScreen> createState()=>_DayGalaxyScreenState();}
class _DayGalaxyScreenState extends State<DayGalaxyScreen> {
  final Map<int,bool> armed={};
  @override Widget build(BuildContext context){final day=widget.day;return Scaffold(backgroundColor:Colors.transparent,body:PulsarBackdrop(child:SafeArea(child:Column(children:[
    PulsarHeader(title:'${day.day} · ${day.title}',progress:widget.controller.progress(day),onBack:()=>Navigator.pop(context)),
    Expanded(child:day.rest?Center(child:LiquidOrb(size:170,palette:PulsarPalette.values[day.palette],value:1,total:1,complete:true,showValue:false)):LayoutBuilder(builder:(context,box)=>Stack(children:[Positioned.fill(child:CustomPaint(painter:DayLinesPainter())),..._exerciseNodes(box.biggest)])))
  ]))));}
  List<Widget> _exerciseNodes(Size size){final day=widget.day;const align=[Alignment(0,-.82),Alignment(-.66,-.34),Alignment(.64,-.24),Alignment(-.58,.26),Alignment(.55,.39),Alignment(0,.82)];const sizes=[110.0,92.0,98.0,88.0,94.0,84.0];return day.exercises.asMap().entries.map((entry){final i=entry.key,e=entry.value,a=align[i%align.length],orb=sizes[i%sizes.length];final x=(a.x+1)/2*size.width-orb/2,y=(a.y+1)/2*size.height-orb/2;final count=widget.controller.count(day,i),done=count>=e.sets;return Positioned(left:x,top:y,child:SizedBox(width:128,child:Column(children:[LiquidOrb(size:orb,palette:PulsarPalette.values[(day.palette+i)%PulsarPalette.values.length],value:count.clamp(0,e.sets),total:e.sets,complete:done,armed:armed[i]??false,entryDelay:Duration(milliseconds:i*90),onTap:()=>_tapExercise(i,e)),const SizedBox(height:2),Text(e.name,maxLines:1,overflow:TextOverflow.ellipsis,textAlign:TextAlign.center,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w700)),Text(e.reps,style:const TextStyle(fontSize:7,color:Color(0xFF687586)))])));}).toList();}
  Future<void> _tapExercise(int index,ExercisePlan e) async {final current=widget.controller.count(widget.day,index);if(current>=e.sets){if(armed[index]??false){await HapticFeedback.mediumImpact();armed[index]=false;await widget.controller.setCount(widget.day,index,0);}else{await HapticFeedback.selectionClick();setState(()=>armed[index]=true);}return;}final next=current+1;if(next>=e.sets){await HapticFeedback.heavyImpact();}else{await HapticFeedback.lightImpact();}armed[index]=false;await widget.controller.setCount(widget.day,index,next);if(mounted)setState((){});}
}
class DayLinesPainter extends CustomPainter {@override void paint(Canvas canvas,Size size){final p=Paint()..color=const Color(0x101B2B3D)..strokeWidth=.65..style=PaintingStyle.stroke;canvas.drawPath(Path()..moveTo(size.width*.5,size.height*.1)..cubicTo(size.width*.12,size.height*.2,size.width*.14,size.height*.38,size.width*.32,size.height*.5)..cubicTo(size.width*.68,size.height*.67,size.width*.82,size.height*.53,size.width*.78,size.height*.39)..moveTo(size.width*.5,size.height*.1)..cubicTo(size.width*.82,size.height*.23,size.width*.74,size.height*.47,size.width*.47,size.height*.62)..cubicTo(size.width*.25,size.height*.74,size.width*.42,size.height*.84,size.width*.5,size.height*.9),p);}@override bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;}

class RecordsScreen extends StatelessWidget {const RecordsScreen({required this.controller,super.key});final PulsarController controller;@override Widget build(BuildContext context){final sets=controller.completed.values.fold<int>(0,(n,m)=>n+m.values.fold<int>(0,(a,b)=>a+b));final days=controller.plan.where((d)=>controller.progress(d)>=1).length;return Column(children:[const PulsarHeader(title:'ARCHIVE'),Expanded(child:ListView(padding:const EdgeInsets.fromLTRB(20,28,20,30),children:[Row(children:[_Metric(value:'$sets',label:'SETS'),const SizedBox(width:12),_Metric(value:'$days',label:'DAYS'),const SizedBox(width:12),const _Metric(value:'9',label:'STREAK')]),const SizedBox(height:34),Wrap(alignment:WrapAlignment.spaceAround,runSpacing:24,children:controller.plan.map((day)=>Column(children:[LiquidOrb(size:78,palette:PulsarPalette.values[day.palette],value:(controller.progress(day)*100).round(),total:100,complete:controller.progress(day)>=1,showValue:false),Text(day.day,style:const TextStyle(fontSize:8,color:Color(0xFF758294)))] )).toList())]))]);}}
class _Metric extends StatelessWidget {const _Metric({required this.value,required this.label});final String value,label;@override Widget build(BuildContext context)=>Expanded(child:Container(height:86,decoration:BoxDecoration(border:Border.all(color:const Color(0x142C3B4E)),borderRadius:BorderRadius.circular(20),color:const Color(0x88101825)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Text(value,style:const TextStyle(fontSize:24,fontWeight:FontWeight.w700)),Text(label,style:const TextStyle(fontSize:7,color:Color(0xFF6D798A),letterSpacing:1.3))])));}

class SettingsScreen extends StatefulWidget {const SettingsScreen({required this.controller,super.key});final PulsarController controller;@override State<SettingsScreen> createState()=>_SettingsScreenState();}
class _SettingsScreenState extends State<SettingsScreen> {
  @override Widget build(BuildContext context)=>Column(children:[const PulsarHeader(title:'WEEKLY PLAN'),Expanded(child:ListView(padding:const EdgeInsets.fromLTRB(14,8,14,28),children:[...widget.controller.plan.map(_dayTile),const SizedBox(height:14),ListTile(shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18),side:const BorderSide(color:Color(0x142C3B4E))),leading:const Icon(Icons.restart_alt_rounded),title:const Text('Clear training records',style:TextStyle(fontSize:12)),onTap:(){HapticFeedback.mediumImpact();widget.controller.clearRecords();})]))]);
  Widget _dayTile(WorkoutDay day)=>Container(margin:const EdgeInsets.only(bottom:8),decoration:BoxDecoration(color:const Color(0xAA101824),borderRadius:BorderRadius.circular(20),border:Border.all(color:const Color(0x142F4054))),child:ExpansionTile(shape:const Border(),collapsedShape:const Border(),leading:LiquidOrb(size:48,palette:PulsarPalette.values[day.palette],value:0,total:1,showValue:false),title:Text('${day.day} · ${day.title}',style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700)),subtitle:Text('${day.exercises.length} exercises',style:const TextStyle(fontSize:8)),children:[...day.exercises.asMap().entries.map((entry)=>_exerciseEditor(day,entry.key,entry.value)),TextButton.icon(onPressed:(){setState(()=>day.exercises.add(ExercisePlan(name:'新训练动作',target:'目标肌群',sets:3,reps:'12')));widget.controller.updatePlan();},icon:const Icon(Icons.add,size:16),label:const Text('Add exercise',style:TextStyle(fontSize:10))),const SizedBox(height:8)]));
  Widget _exerciseEditor(WorkoutDay day,int index,ExercisePlan e)=>Padding(padding:const EdgeInsets.fromLTRB(16,7,12,7),child:Column(children:[TextFormField(initialValue:e.name,style:const TextStyle(fontSize:11),decoration:const InputDecoration(isDense:true,border:InputBorder.none),onChanged:(v){e.name=v;widget.controller.updatePlan();}),Row(children:[SizedBox(width:88,child:TextFormField(initialValue:e.reps,style:const TextStyle(fontSize:9,color:Color(0xFF8996A5)),decoration:const InputDecoration(isDense:true,border:InputBorder.none),onChanged:(v){e.reps=v;widget.controller.updatePlan();})),const Spacer(),IconButton(onPressed:(){if(e.sets>1)setState(()=>e.sets--);widget.controller.updatePlan();},icon:const Icon(Icons.remove,size:14)),Text('${e.sets} sets',style:const TextStyle(fontSize:9)),IconButton(onPressed:(){setState(()=>e.sets++);widget.controller.updatePlan();},icon:const Icon(Icons.add,size:14)),IconButton(onPressed:(){setState(()=>day.exercises.removeAt(index));widget.controller.updatePlan();},icon:const Icon(Icons.delete_outline,size:15,color:Color(0xFF9A6978)))]) ]));
}
