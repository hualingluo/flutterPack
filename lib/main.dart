import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

// --- 1. 数据模型定义 (根据你的JSON设计) ---

class GameData {
  final Map<String, GameNode> nodes;
  final GameViewport viewport;

  GameData({required this.nodes, required this.viewport});

  factory GameData.fromJson(Map<String, dynamic> json) {
    var nodesMap = <String, GameNode>{};
    if (json['nodes'] != null) {
      json['nodes'].forEach((key, value) {
        nodesMap[key] = GameNode.fromJson(value);
      });
    }
    return GameData(
      nodes: nodesMap,
      viewport: GameViewport.fromJson(json['viewport'] ?? {}),
    );
  }
}

class GameNode {
  final String id;
  final String title;
  final String content;
  final String mediaSrc;
  final List<NodeOption> options;

  GameNode({
    required this.id,
    required this.title,
    required this.content,
    required this.mediaSrc,
    required this.options,
  });

  factory GameNode.fromJson(Map<String, dynamic> json) {
    var optionsList = <NodeOption>[];
    if (json['options'] != null) {
      json['options'].forEach((v) {
        optionsList.add(NodeOption.fromJson(v));
      });
    }
    return GameNode(
      id: json['id'] ?? "",
      title: json['title'] ?? "",
      content: json['content'] ?? "",
      // 处理这里：虽然你的JSON里有的type是none，但如果有链接我们依然尝试读取
      mediaSrc: json['mediaSrc'] ?? "", 
      options: optionsList,
    );
  }
}

class NodeOption {
  final String label;
  final String targetId;

  NodeOption({required this.label, required this.targetId});

  factory NodeOption.fromJson(Map<String, dynamic> json) {
    return NodeOption(
      label: json['label'] ?? "",
      targetId: json['targetId'] ?? "",
    );
  }
}

class GameViewport {
  final double x;
  final double y;

  GameViewport({required this.x, required this.y});

  factory GameViewport.fromJson(Map<String, dynamic> json) {
    return GameViewport(
      x: (json['x'] ?? 0).toDouble(),
      y: (json['y'] ?? 0).toDouble(),
    );
  }
}

// --- 2. 模拟输入的 JSON 数据 ---
// 在实际开发中，你可以通过 rootBundle.loadString 读取文件
const String rawJson = '''
{
  "nodes": {
    "start": {
      "id": "start",
      "title": "序章：苏醒",
      "type": "scene",
      "content": "你在一个冷冻舱中醒来。警报声在耳边回荡，空气中弥漫着臭氧和铁锈的味道。控制台闪烁着微弱的红光，你什么都想不起来。",
      "mediaType": "none",
      "mediaSrc": "https://www.runoob.com/try/demo_source/mov_bbb.mp4",
      "audioSrc": "",
      "x": 100,
      "y": 300,
      "options": [
        { "id": "o1", "label": "检查控制台", "targetId": "n2" },
        { "id": "o2", "label": "强行打开舱门", "targetId": "n3" }
      ]
    },
    "n2": {
      "id": "n2",
      "title": "系统日志",
      "type": "decision",
      "content": "控制台屏幕闪烁不定。上面显示着 '致命错误：船体破损'。你发现了一段未发送的求救信号。",
      "mediaType": "none",
      "mediaSrc": "https://www.runoob.com/try/demo_source/mov_bbb.mp4",
      "audioSrc": "",
      "x": 500,
      "y": 200,
      "options": []
    },
    "n3": {
      "id": "n3",
      "title": "黑暗走廊",
      "type": "scene",
      "content": "舱门在火花中滑开。走廊一片漆黑，远处的应急灯忽明忽暗，仿佛有什么东西在阴影中移动。",
      "mediaType": "none",
      "mediaSrc": "https://www.runoob.com/try/demo_source/mov_bbb.mp4",
      "audioSrc": "",
      "x": 500,
      "y": 400,
      "options": []
    }
  },
  "viewport": { "x": 0, "y": 0, "zoom": 1 }
}
''';

// --- 3. 应用程序主入口 ---

void main() {
  // Initialize media_kit
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CineGenesis Player',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const InteractiveMoviePage(),
    );
  }
}

class InteractiveMoviePage extends StatefulWidget {
  const InteractiveMoviePage({super.key});

  @override
  State<InteractiveMoviePage> createState() => _InteractiveMoviePageState();
}

class _InteractiveMoviePageState extends State<InteractiveMoviePage> {
  GameData? _gameData;
  GameNode? _currentNode;
  late final Player _mainPlayer; // 主播放器
  late final Player _preloadPlayer; // 预加载播放器
  late final VideoController _videoController;
  bool _isVideoLoading = true;
  bool _useMainPlayer = true; // 标记当前使用哪个播放器
  final Map<String, Player> _preloadedPlayers = {}; // 预加载的播放器缓存

  @override
  void initState() {
    super.initState();

    // 初始化两个播放器
    _mainPlayer = Player();
    _preloadPlayer = Player();
    _videoController = VideoController(_mainPlayer);

    // 监听主播放器状态
    _mainPlayer.stream.playing.listen((isPlaying) {
      if (isPlaying && mounted) {
        setState(() {
          _isVideoLoading = false;
        });

        // 视频开始播放后,预加载下一个可能的视频
        if (_currentNode != null) {
          _preloadNextVideos(_currentNode!);
        }
      }
    });

    _loadGame();
  }

  // 加载并解析 JSON
  void _loadGame() {
    try {
      final Map<String, dynamic> jsonMap = jsonDecode(rawJson);
      final gameData = GameData.fromJson(jsonMap);
      
      setState(() {
        _gameData = gameData;
        // 默认从 ID 为 "start" 的节点开始
        _currentNode = gameData.nodes['start'];
      });
      
      if (_currentNode != null) {
        _initializeVideo(_currentNode!.mediaSrc);
      }
    } catch (e) {
      debugPrint("Error loading JSON: $e");
    }
  }

  // 初始化或切换视频
  Future<void> _initializeVideo(String url, {Player? player}) async {
    if (url.isEmpty) return;

    final targetPlayer = player ?? _mainPlayer;

    // 设置加载状态
    if (mounted && player == null) {
      setState(() {
        _isVideoLoading = true;
      });
    }

    // Open video using media_kit
    await targetPlayer.open(Media(url), play: player == null);

    // Set the player to loop mode
    targetPlayer.setPlaylistMode(PlaylistMode.loop);
  }

  // 预加载下一个节点的视频
  Future<void> _preloadNextVideos(GameNode currentNode) async {
    if (currentNode.options.isEmpty) return;

    for (var option in currentNode.options) {
      final targetId = option.targetId;
      if (_gameData == null || !_gameData!.nodes.containsKey(targetId)) continue;

      final nextNode = _gameData!.nodes[targetId]!;
      final videoUrl = nextNode.mediaSrc;

      // 如果已经预加载过,跳过
      if (_preloadedPlayers.containsKey(videoUrl)) continue;

      // 创建新的播放器用于预加载
      final preloadPlayer = Player();
      await preloadPlayer.open(Media(videoUrl), play: false);
      preloadPlayer.setPlaylistMode(PlaylistMode.loop);

      _preloadedPlayers[videoUrl] = preloadPlayer;
    }
  }

  // 核心逻辑：跳转节点
  void _jumpToNode(String targetId) async {
    if (_gameData == null || !_gameData!.nodes.containsKey(targetId)) return;

    final nextNode = _gameData!.nodes[targetId]!;
    final videoUrl = nextNode.mediaSrc;

    setState(() {
      _currentNode = nextNode;
      _isVideoLoading = true;
    });

    // 检查是否有预加载的播放器
    if (_preloadedPlayers.containsKey(videoUrl)) {
      // 使用预加载的播放器,实现秒开
      final preloadedPlayer = _preloadedPlayers[videoUrl]!;

      // 交换播放器
      final oldController = _videoController;
      _videoController = VideoController(preloadedPlayer);

      // 播放视频
      await preloadedPlayer.play();

      // 从缓存中移除
      _preloadedPlayers.remove(videoUrl);

      // 释放旧的播放器资源(延迟释放,避免切换闪烁)
      Future.delayed(const Duration(milliseconds: 500), () {
        oldController.player.dispose();
      });
    } else {
      // 没有预加载,使用正常加载
      await _mainPlayer.open(Media(videoUrl), play: true);
      _mainPlayer.setPlaylistMode(PlaylistMode.loop);
    }
  }

  @override
  void dispose() {
    _mainPlayer.dispose();
    _preloadPlayer.dispose();

    // 释放所有预加载的播放器
    for (var player in _preloadedPlayers.values) {
      player.dispose();
    }
    _preloadedPlayers.clear();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentNode == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 背景层：视频播放器 (media_kit)
          Video(
            controller: _videoController,
            controls: NoVideoControls,
          ),

          // 1.5 加载指示器层
          if (_isVideoLoading)
            Container(
              color: Colors.black87,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                    ),
                    SizedBox(height: 20),
                    Text(
                      '加载视频中...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 2. 遮罩层：让文字更清晰
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.8), // 底部变黑以便显示文字
                ],
                stops: const [0.5, 1.0],
              ),
            ),
          ),

          // 3. 内容层：文字和按钮
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 标题
                Text(
                  _currentNode!.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(height: 10),
                // 剧情文本
                Text(
                  _currentNode!.content,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 2, color: Colors.black)],
                  ),
                ),
                const SizedBox(height: 30),
                // 选项按钮区
                if (_currentNode!.options.isEmpty)
                  // 结局或无选项时的重置按钮
                  ElevatedButton(
                    onPressed: () => _jumpToNode('start'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text("重新开始"),
                  )
                else
                  // 动态生成选项
                  ..._currentNode!.options.map((option) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.white.withOpacity(0.2),
                          side: const BorderSide(color: Colors.white, width: 1),
                        ),
                        onPressed: () => _jumpToNode(option.targetId),
                        child: Text(
                          option.label,
                          style: const TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    );
                  }).toList(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}