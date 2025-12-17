import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';

// 替换为你的有道API信息（已填好你提供的ID/密钥）
const String APP_KEY = '6a4a11c32bfaac2e';
const String APP_SECRET = '1MTt6DjhwX6FcRy04lM5O1Pf1g0j0QUb';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '英文学习助手',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomePage(),
      debugShowCheckedModeBanner: false, // 隐藏调试水印
    );
  }
}

// 首页：功能入口
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('英文学习助手')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TranslatePage()),
                ),
                child: const Text('句子翻译 & 跟读评分'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 60),
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const VocabularyPracticePage()),
                ),
                child: const Text('三级词汇练习'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 60),
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------- 模块1：句子翻译 + 跟读评分 ---------------
class TranslatePage extends StatefulWidget {
  const TranslatePage({super.key});

  @override
  State<TranslatePage> createState() => _TranslatePageState();
}

class _TranslatePageState extends State<TranslatePage> {
  final TextEditingController _inputController = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  
  String _translateResult = '';
  String _scoreText = '';
  String _suggestionText = '';
  bool _isListening = false;

  // 有道翻译核心方法（已修复MD5签名）
  Future<void> _translate() async {
    String text = _inputController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入要翻译的内容！'), backgroundColor: Colors.orange),
      );
      return;
    }

    // 生成签名参数
    String salt = DateTime.now().millisecondsSinceEpoch.toString();
    String signStr = APP_KEY + text + salt + APP_SECRET;
    String sign = md5.convert(utf8.encode(signStr)).toString();

    try {
      final response = await http.post(
        Uri.parse('https://openapi.youdao.com/api'),
        body: {
          'q': text,
          'from': 'auto',
          'to': 'auto',
          'appKey': APP_KEY,
          'salt': salt,
          'sign': sign,
          'signType': 'v3',
        },
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['errorCode'] == '0') {
          setState(() {
            _translateResult = (result['translation'] as List).first.toString();
            _scoreText = '';
            _suggestionText = '';
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('翻译失败：${result['errorCode']}'), backgroundColor: Colors.red),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('网络错误，请检查网络！'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('翻译出错：$e'), backgroundColor: Colors.red),
      );
    }
  }

  // 播放标准发音（自动识别中英）
  Future<void> _playPronunciation() async {
    if (_translateResult.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先翻译获取内容！'), backgroundColor: Colors.orange),
      );
      return;
    }

    // 判断语言类型
    bool isEnglish = _translateResult.contains(RegExp(r'[a-zA-Z]'));
    await _flutterTts.setLanguage(isEnglish ? 'en-US' : 'zh-CN');
    await _flutterTts.setSpeechRate(0.5); // 语速放慢，适合学习
    await _flutterTts.setVolume(1.0);    // 音量最大
    await _flutterTts.speak(_translateResult);
  }

  // 跟读录音 + 发音评分（文本相似度对比）
  Future<void> _startListening() async {
    if (_translateResult.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先翻译获取标准句子！'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (!_isListening) {
      bool available = await _speechToText.initialize(
        onStatus: (status) => setState(() => _isListening = status == 'listening'),
        onError: (error) => {
          setState(() => _isListening = false),
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('语音识别错误：${error.errorMsg}'), backgroundColor: Colors.red),
          )
        },
      );

      if (available) {
        setState(() => _isListening = true);
        _speechToText.listen(
          localeId: 'en-US', // 识别英文（跟读英文时用）
          onResult: (result) {
            if (result.finalResult) {
              setState(() => _isListening = false);
              _scorePronunciation(result.recognizedWords);
            }
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speechToText.stop();
    }
  }

  // 发音评分逻辑（基础版文本相似度）
  void _scorePronunciation(String userText) {
    String standard = _translateResult.toLowerCase().replaceAll(' ', '');
    String user = userText.toLowerCase().replaceAll(' ', '');

    int commonChars = Set.from(standard.split('')).intersection(Set.from(user.split(''))).length;
    double similarity = standard.isEmpty ? 0 : (commonChars / standard.length) * 100;
    int score = similarity.toInt();

    String suggestion;
    if (score >= 90) {
      suggestion = '发音非常标准！继续保持～';
    } else if (score >= 70) {
      suggestion = '发音基本准确，个别单词有偏差，建议再跟读一遍。';
    } else if (score >= 50) {
      suggestion = '发音有明显偏差，重点模仿标准句子的发音，放慢语速跟读。';
    } else {
      suggestion = '发音偏差较大，先听标准发音，逐词模仿后再整句跟读。';
    }

    setState(() {
      _scoreText = '发音评分：$score 分';
      _suggestionText = suggestion;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('句子翻译 & 跟读')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 输入框
              TextField(
                controller: _inputController,
                decoration: const InputDecoration(
                  hintText: '输入中文/英文，点击翻译（例如：Hello World / 你好世界）',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(15),
                ),
                maxLines: 3,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 15),

              // 翻译按钮
              ElevatedButton(
                onPressed: _translate,
                child: const Text('立即翻译', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
              const SizedBox(height: 20),

              // 翻译结果
              const Text(
                '翻译结果：',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                _translateResult.isEmpty ? '暂无翻译结果' : _translateResult,
                style: const TextStyle(fontSize: 20, color: Colors.blueAccent),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 25),

              // 发音/跟读按钮
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _playPronunciation,
                      child: const Text('播放标准发音', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _startListening,
                      child: Text(
                        _isListening ? '停止跟读' : '开始跟读',
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isListening ? Colors.red : Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),

              // 评分结果
              if (_scoreText.isNotEmpty)
                Column(
                  children: [
                    Text(
                      _scoreText,
                      style: const TextStyle(fontSize: 18, color: Colors.orange),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _suggestionText,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------- 模块2：三级词汇练习（选择/填空/拼写） ---------------
class VocabularyPracticePage extends StatefulWidget {
  const VocabularyPracticePage({super.key});

  @override
  State<VocabularyPracticePage> createState() => _VocabularyPracticePageState();
}

class _VocabularyPracticePageState extends State<VocabularyPracticePage> {
  // 难度/题型选择
  int _selectedDifficulty = 1; // 1=初级，2=中级，3=高级
  String _selectedType = 'choice'; // choice=选择，blank=填空，spell=拼写

  // 词汇数据库（扩展可自行添加更多单词）
  final Map<int, List<Word>> _wordData = {
    1: [ // 初级词汇
      Word('apple', 'a round fruit with red/green skin', 'I eat an apple every day.', '/ˈæpl/'),
      Word('book', 'a set of pages bound together', 'She is reading a story book.', '/bʊk/'),
      Word('cat', 'a small furry animal', 'My cat is black and white.', '/kæt/'),
      Word('desk', 'a piece of furniture for working', 'Put the pen on the desk.', '/desk/'),
      Word('egg', 'oval food from chickens', 'I have an egg for breakfast.', '/eɡ/'),
      Word('fish', 'a water animal with fins', 'There are many fish in the river.', '/fɪʃ/'),
    ],
    2: [ // 中级词汇
      Word('analyse', 'to examine in detail', 'We analyse the data carefully.', '/ˈænəlaɪz/'),
      Word('benefit', 'an advantage from something', 'Exercise has many health benefits.', '/ˈbenɪfɪt/'),
      Word('challenge', 'a difficult task', 'Learning English is a big challenge.', '/ˈtʃælɪndʒ/'),
      Word('develop', 'to grow or improve', 'Develop your English skills every day.', '/dɪˈveləp/'),
      Word('environment', 'the natural world around us', 'We must protect the environment.', '/ɪnˈvaɪrənmənt/'),
      Word('friendly', 'kind and pleasant', 'She is a very friendly girl.', '/ˈfrendli/'),
    ],
    3: [ // 高级词汇
      Word('ambiguous', 'having multiple meanings', 'His words are ambiguous.', '/æmˈbɪɡjuəs/'),
      Word('collaborate', 'to work together with others', 'We collaborate with foreign teams.', '/kəˈlæbəreɪt/'),
      Word('deteriorate', 'to become worse over time', 'His pronunciation deteriorated.', '/dɪˈtɪəriəreɪt/'),
      Word('ephemeral', 'lasting for a very short time', 'Happiness is often ephemeral.', '/ɪˈfemərəl/'),
      Word('fluctuate', 'to change in amount or level', 'Vocabulary retention fluctuates.', '/ˈflʌktʃueɪt/'),
      Word('perseverance', 'continued effort despite difficulties', 'Perseverance leads to success.', '/ˌpɜːsəˈvɪərəns/'),
    ]
  };

  // 练习状态
  List<Question> _questions = [];
  int _currentQIndex = 0;
  int _correctCount = 0;
  final TextEditingController _spellController = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _generateQuestions();
  }

  // 生成题目（随机选5题）
  void _generateQuestions() {
    List<Word> words = _wordData[_selectedDifficulty]!;
    _questions.clear();
    _currentQIndex = 0;
    _correctCount = 0;

    // 随机打乱单词，取前5题
    words = List.from(words)..shuffle(Random());
    for (int i = 0; i < min(5, words.length); i++) {
      Word word = words[i];
      if (_selectedType == 'choice') {
        // 选择题：根据释义选单词
        List<String> options = [word.word];
        // 添加干扰项
        words.where((w) => w.word != word.word).take(2).forEach((w) => options.add(w.word));
        options.shuffle();
        _questions.add(Question(
          text: 'What is the word for: ${word.definition}',
          type: 'choice',
          options: options,
          correctAnswer: word.word,
        ));
      } else if (_selectedType == 'blank') {
        // 填空题：补全例句
        String example = word.example.replaceAll(word.word, '____');
        List<String> options = [word.word];
        words.where((w) => w.word != word.word).take(2).forEach((w) => options.add(w.word));
        options.shuffle();
        _questions.add(Question(
          text: 'Fill in the blank: $example',
          type: 'blank',
          options: options,
          correctAnswer: word.word,
        ));
      } else if (_selectedType == 'spell') {
        // 拼写题：根据释义拼单词
        _questions.add(Question(
          text: 'Spell the word: ${word.definition}\n(Pronunciation: ${word.pronunciation})',
          type: 'spell',
          correctAnswer: word.word,
        ));
      }
    }
  }

  // 答题判断
  void _answerQuestion(String userAnswer) {
    Question q = _questions[_currentQIndex];
    bool isCorrect = userAnswer.toLowerCase() == q.correctAnswer.toLowerCase();
    if (isCorrect) _correctCount++;

    // 提示答题结果
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isCorrect 
          ? '✅ 正确！' 
          : '❌ 错误，正确答案：${q.correctAnswer}'),
        backgroundColor: isCorrect ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );

    // 下一题 或 展示最终结果
    if (_currentQIndex < _questions.length - 1) {
      setState(() => _currentQIndex++);
      _spellController.clear();
    } else {
      double accuracy = (_correctCount / _questions.length) * 100;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('练习完成！'),
          content: Text(
            '得分：$_correctCount/${_questions.length}\n正确率：${accuracy.toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _generateQuestions();
                  _spellController.clear();
                });
              },
              child: const Text('重新练习', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      );
    }
  }

  // 播放单词发音
  Future<void> _playWordPronunciation(String word) async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.4);
    await _flutterTts.speak(word);
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) return const Center(child: CircularProgressIndicator());
    Question currentQ = _questions[_currentQIndex];

    return Scaffold(
      appBar: AppBar(title: const Text('三级词汇练习')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 难度选择
              const Text('选择难度：', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (int i = 1; i <= 3; i++)
                    ElevatedButton(
                      onPressed: () => setState(() {
                        _selectedDifficulty = i;
                        _generateQuestions();
                      }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedDifficulty == i ? Colors.blue : Colors.grey[300],
                        foregroundColor: _selectedDifficulty == i ? Colors.white : Colors.black,
                        minimumSize: const Size(80, 40),
                      ),
                      child: Text(i == 1 ? '初级' : i == 2 ? '中级' : '高级'),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // 题型选择
              const Text('选择题型：', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var type in [('choice', '选择'), ('blank', '填空'), ('spell', '拼写')])
                    ElevatedButton(
                      onPressed: () => setState(() {
                        _selectedType = type.$1;
                        _generateQuestions();
                      }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedType == type.$1 ? Colors.green : Colors.grey[300],
                        foregroundColor: _selectedType == type.$1 ? Colors.white : Colors.black,
                        minimumSize: const Size(80, 40),
                      ),
                      child: Text(type.$2),
                    ),
                ],
              ),
              const SizedBox(height: 30),

              // 题目进度
              Text(
                '题目 ${_currentQIndex + 1}/${_questions.length}',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // 题目内容
              Text(
                currentQ.text,
                style: const TextStyle(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // 答题区域
              if (currentQ.type == 'choice' || currentQ.type == 'blank')
                Column(
                  children: currentQ.options!.map((option) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ElevatedButton(
                        onPressed: () => _answerQuestion(option),
                        child: Text(option, style: const TextStyle(fontSize: 18)),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                    );
                  }).toList(),
                )
              else if (currentQ.type == 'spell')
                Column(
                  children: [
                    TextField(
                      controller: _spellController,
                      decoration: const InputDecoration(
                        hintText: '请输入单词拼写（小写即可）',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(15),
                        fontSize: 18,
                      ),
                      style: const TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _playWordPronunciation(currentQ.correctAnswer),
                            child: const Text('播放单词发音', style: TextStyle(fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _answerQuestion(_spellController.text.trim()),
                            child: const Text('提交答案', style: TextStyle(fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// 数据模型：单词
class Word {
  final String word;
  final String definition;
  final String example;
  final String pronunciation;

  Word(this.word, this.definition, this.example, this.pronunciation);
}

// 数据模型：题目
class Question {
  final String text;
  final String type;
  final List<String>? options;
  final String correctAnswer;

  Question({
    required this.text,
    required this.type,
    this.options,
    required this.correctAnswer,
  });
}