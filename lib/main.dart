import 'packagefluttermaterial.dart';

void main() {
  runApp(const MyEnglishLearningApp());
}

class MyEnglishLearningApp extends StatelessWidget {
  const MyEnglishLearningApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title '英语学习App',
      theme ThemeData(
        primarySwatch Colors.blue,
        visualDensity VisualDensity.adaptivePlatformDensity,
      ),
      home const EnglishLearningHomePage(),
    );
  }
}

class EnglishLearningHomePage extends StatefulWidget {
  const EnglishLearningHomePage({super.key});

  @override
  StateEnglishLearningHomePage createState() = _EnglishLearningHomePageState();
}

class _EnglishLearningHomePageState extends StateEnglishLearningHomePage {
   输入框控制器（用于获取设置输入内容）
  final TextEditingController _wordController = TextEditingController();
   存储输入的单词
  String _inputWord = ;

   点击「查询」按钮的逻辑
  void _queryWord() {
    setState(() {
      _inputWord = _wordController.text;
    });
     可以扩展：单词查询、发音等逻辑
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content Text(查询单词：$_inputWord)),
    );
  }

   点击「清空」按钮的逻辑
  void _clearInput() {
    setState(() {
      _wordController.clear();
      _inputWord = ;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar AppBar(
        title const Text(英语单词学习),
        centerTitle true,
      ),
      body Padding(
        padding const EdgeInsets.all(16.0),
        child Column(
          crossAxisAlignment CrossAxisAlignment.stretch,
          children [
             1. 单词输入框（修复了InputDecoration的fontSize错误）
            TextField(
              controller _wordController,
              decoration const InputDecoration(
                labelText 请输入英语单词,
                labelStyle TextStyle(fontSize 18),  标签文字大小（正确写法）
                hintText 例如：apple,
                hintStyle TextStyle(fontSize 16),  提示文字大小（正确写法）
                border OutlineInputBorder(
                  borderRadius BorderRadius.all(Radius.circular(8)),
                ),
                contentPadding EdgeInsets.symmetric(horizontal 16, vertical 12),
              ),
               输入框内文字大小（正确写法：写在TextField的style里，而非InputDecoration）
              style const TextStyle(fontSize 18),
              keyboardType TextInputType.text,
            ),

            const SizedBox(height 20),

             2. 按钮行（修复了ElevatedButton的fontSize错误）
            Row(
              children [
                 查询按钮
                Expanded(
                  child ElevatedButton(
                     正确设置按钮文字大小：用textStyle
                    style ElevatedButton.styleFrom(
                      textStyle const TextStyle(fontSize 18),  按钮文字大小（正确写法）
                      padding const EdgeInsets.symmetric(vertical 12),
                      shape RoundedRectangleBorder(
                        borderRadius BorderRadius.circular(8),
                      ),
                    ),
                    onPressed _queryWord,
                    child const Text(查询单词),
                  ),
                ),

                const SizedBox(width 10),

                 清空按钮
                Expanded(
                  child ElevatedButton(
                    style ElevatedButton.styleFrom(
                      textStyle const TextStyle(fontSize 18),  按钮文字大小（正确写法）
                      backgroundColor Colors.grey,
                      padding const EdgeInsets.symmetric(vertical 12),
                      shape RoundedRectangleBorder(
                        borderRadius BorderRadius.circular(8),
                      ),
                    ),
                    onPressed _clearInput,
                    child const Text(清空输入),
                  ),
                ),
              ],
            ),

            const SizedBox(height 30),

             3. 显示查询结果
            if (_inputWord.isNotEmpty)
              Container(
                padding const EdgeInsets.all(16),
                decoration BoxDecoration(
                  color Colors.blue[50],
                  borderRadius BorderRadius.circular(8),
                ),
                child Column(
                  crossAxisAlignment CrossAxisAlignment.start,
                  children [
                    const Text(
                      查询结果：,
                      style TextStyle(fontSize 18, fontWeight FontWeight.bold),
                    ),
                    const SizedBox(height 8),
                    Text(
                      _inputWord,
                      style const TextStyle(fontSize 20, color Colors.blue),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

   释放控制器资源（避免内存泄漏）
  @override
  void dispose() {
    _wordController.dispose();
    super.dispose();
  }
}