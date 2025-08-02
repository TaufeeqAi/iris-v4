import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../config/app_config.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/loading_overlay.dart';

class CreateAgentScreen extends StatefulWidget {
  const CreateAgentScreen({super.key});

  @override
  State<CreateAgentScreen> createState() => _CreateAgentScreenState();
}

class _CreateAgentScreenState extends State<CreateAgentScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _nameController = TextEditingController();
  final _secretsController = TextEditingController();
  final _systemController = TextEditingController();
  final _bioController = TextEditingController();
  final _loreController = TextEditingController();
  final _knowledgeAreasController = TextEditingController();
  final _messageExamplesController = TextEditingController();
  final _styleController = TextEditingController();

  bool _isLoading = false;
  String _selectedProvider = 'Groq';
  String _llmModel = AppConfig.defaultModel;
  double _temperature = AppConfig.defaultTemperature;
  int _maxTokens = AppConfig.defaultMaxTokens;

  final List<String> _availableProviders = [
    'Groq',
    'Anthropic',
    "OpenAI",
    "Google",
  ];
  final Map<String, List<String>> _providerModels = {
    'openai': [
      'gpt-3.5-turbo',
      'gpt-3.5-turbo-16k',
      'gpt-4',
      'gpt-4-32k',
      'gpt-4-turbo',
      'gpt-4.1',
    ],
    'anthropic': [
      'Claude 3 Haiku',
      'Claude 3 Sonnet',
      'Claude 3 Opus',
      'claude‑4‑opus',
      'claude‑4‑sonnet',
    ],
    'groq': [
      'moonshotai/kimi‑k2‑instruct',
      'meta‑llama/llama‑4‑scout‑17b‑16e‑instruct',
      'meta‑llama/llama‑4‑maverick‑17b‑128e‑instruct',
      'meta‑llama/llama‑guard‑4‑12b‑instruct',
      'gemma‑2‑9b‑it', // Google model on GroqCloud
    ],
    'google': ['gemini‑1.5‑pro', 'gemini‑2.5‑flash', 'gemini‑2.5‑pro'],
  };

  final Map<String, int> _modelMaxTokenLimits = {
    'gpt-3.5‑turbo': 4096,
    'gpt‑3.5‑turbo‑16k': 16384,
    'gpt‑4': 8192,
    'gpt‑4‑32k': 32768,
    'gpt‑4‑turbo': 131072, // Turbo supports 128K
    'gpt‑4.1': 1000000, // GPT‑4.1 supports ~1M tokens

    'Claude 3 Haiku': 200000, 'Claude 3 Sonnet': 200000,
    'Claude 3 Opus': 200000,
    'claude‑4‑opus': 200000, 'claude‑4‑sonnet': 200000,
    'moonshotai/kimi‑k2‑instruct': 131072,
    'meta‑llama/llama‑4‑scout‑17b‑16e‑instruct': 131072,
    'meta‑llama/llama‑4‑maverick‑17b‑128e‑instruct': 131072, // preview capacity
    'meta‑llama/llama‑guard‑4‑12b‑instruct': 131072,
    'gemma‑2‑9b‑it': 8192,

    'gemini‑1.5‑pro': 1_048_576,
    'gemini‑2.5‑flash': 1_048_576,
    'gemini‑2.5‑pro': 1_048_576,
  };

  final Map<String, int> _modelMaxOutputLimits = {
    'gpt-3.5-turbo': 4096,
    'gpt-3.5-turbo-16k': 16384,
    'gpt-4': 8192,
    'gpt-4-32k': 32768,
    'gpt-4-turbo': 131072,
    'gpt-4.1': 1_000_000,

    'claude-4-opus': 32768,
    'claude-4-sonnet': 65536,

    'meta-llama/llama-4-scout-17b-16e-instruct': 8192,
    'meta-llama/llama-4-maverick-17b-128e-instruct': 8192,
    'meta-llama/llama-guard-4-12b-instruct': 131072,
    'gemma-2-9b-it': 8192,

    'gemini-1.5-pro': 8192,
    'gemini-2.5-flash': 65535,
    'gemini-2.5-pro': 65535,
  };

  @override
  void dispose() {
    _nameController.dispose();
    _secretsController.dispose();
    _systemController.dispose();
    _bioController.dispose();
    _loreController.dispose();
    _knowledgeAreasController.dispose();
    _messageExamplesController.dispose();
    _styleController.dispose();
    super.dispose();
  }

  /// Sends the agent data to the API to be created.
  Future<void> _createAgent(Map<String, dynamic> agentData) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = ApiService(authService.token!);

      print('🚀 Sending agent data to API...');
      final response = await apiService.createAgent(agentData);
      print('✅ Agent created: $response');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agent created successfully!')),
      );

      _clearForm();
    } catch (e) {
      print('❌ Failed to create agent: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create agent: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Clears all the form fields and resets state variables.
  void _clearForm() {
    _nameController.clear();
    _secretsController.clear();
    _systemController.clear();
    _bioController.clear();
    _loreController.clear();
    _knowledgeAreasController.clear();
    _messageExamplesController.clear();
    _styleController.clear();
    setState(() {
      _selectedProvider = 'Groq';
      _llmModel = AppConfig.defaultModel;
      _temperature = AppConfig.defaultTemperature;
      _maxTokens = AppConfig.defaultMaxTokens;
    });
  }

  void _updateModelAndTokenLimits(String provider) {
    final models = _providerModels[provider.toLowerCase()];
    if (models != null && models.isNotEmpty) {
      _llmModel = models.first;
      _maxTokens =
          _modelMaxTokenLimits[_llmModel] ?? AppConfig.defaultMaxTokens;
    }
  }

  /// Creates an agent from the data entered in the form.
  Future<void> _createAgentFromForm() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      print('🔍 Parsing secrets...');
      final secrets = _secretsController.text.isNotEmpty
          ? json.decode(_secretsController.text)
          : {};
      // 🔧 Normalize telegram_api_id
      if (secrets.containsKey('telegram_api_id')) {
        final apiId = secrets['telegram_api_id'];
        if (apiId is String) {
          print("converting telegramID from string to int");
          final parsed = int.tryParse(apiId);
          if (parsed != null) {
            secrets['telegram_api_id'] = parsed; // ✅ Convert to int
            print("Telegram ID converted to INT");
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text("Telegram API ID must be a valid number."),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
            return; // ❌ Don't proceed if invalid
          }
        } else if (apiId is! int) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Telegram API ID must be a number."),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
          return;
        }
      }

      print('🔍 Parsing messageExamples...');
      final messageExamples = _messageExamplesController.text.isNotEmpty
          ? json.decode(_messageExamplesController.text)
          : [];
      print('🔍 Parsing style...');
      final style = _styleController.text.isNotEmpty
          ? json.decode(_styleController.text)
          : {};

      final agentData = {
        'name': _nameController.text,
        'modelProvider': _selectedProvider.toLowerCase(),
        'system': _systemController.text.isEmpty
            ? null
            : _systemController.text,
        'bio': _bioController.text.isEmpty
            ? null
            : _bioController.text.split(',').map((e) => e.trim()).toList(),
        'lore': _loreController.text.isEmpty
            ? null
            : _loreController.text.split(',').map((e) => e.trim()).toList(),
        'knowledgeAreas': _knowledgeAreasController.text.isEmpty
            ? null
            : _knowledgeAreasController.text
                  .split(',')
                  .map((e) => e.trim())
                  .toList(),
        'messageExamples': messageExamples,
        'style': style,
        'settings': {
          'model': _llmModel,
          'temperature': _temperature,
          'maxTokens': _maxTokens,
          'secrets': secrets,
        },
      };
      print('📦 Final agent payload:\n${jsonEncode(agentData)}');
      await _createAgent(agentData);
    } catch (e) {
      print('❌ Error while parsing JSON: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to parse JSON fields: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  /// Handles the process of picking a JSON file and populating the form.
  Future<void> _loadAgentConfigFromFile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('📁 Opening file picker...');
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true, // ✅ ensures we get file.bytes on Web
      );

      if (result == null) {
        print('⚠️ No file selected');
        return;
      }

      final pickedFile = result.files.single;
      String jsonString;

      if (pickedFile.bytes != null) {
        print('📦 Reading from memory bytes...');
        jsonString = utf8.decode(pickedFile.bytes!);
      } else if (pickedFile.path != null) {
        print('📄 Reading from file path: ${pickedFile.path}');
        jsonString = await File(pickedFile.path!).readAsString();
      } else {
        throw Exception('No readable file data found.');
      }

      print('🧾 Raw JSON string:\n$jsonString');
      final agentConfig = json.decode(jsonString) as Map<String, dynamic>;
      print('✅ Parsed agent config');

      _nameController.text = agentConfig['name'] ?? '';
      _systemController.text = agentConfig['system'] ?? '';
      _bioController.text =
          (agentConfig['bio'] as List<dynamic>?)?.join(', ') ?? '';
      _loreController.text =
          (agentConfig['lore'] as List<dynamic>?)?.join(', ') ?? '';
      _knowledgeAreasController.text =
          (agentConfig['knowledgeAreas'] as List<dynamic>?)?.join(', ') ?? '';
      _messageExamplesController.text = agentConfig['messageExamples'] != null
          ? json.encode(agentConfig['messageExamples'])
          : '';
      _styleController.text = agentConfig['style'] != null
          ? json.encode(agentConfig['style'])
          : '';
      print('📝 Populated form fields');

      final settings = agentConfig['settings'] as Map<String, dynamic>?;
      if (settings != null) {
        setState(() {
          _selectedProvider = _availableProviders.firstWhere(
            (p) =>
                p.toLowerCase() ==
                (agentConfig['modelProvider'] ?? '').toLowerCase(),
            orElse: () => AppConfig.defaultModelProvider,
          );

          final availableModels =
              _providerModels[_selectedProvider.toLowerCase()] ?? [];
          final loadedModel = settings['model'] ?? AppConfig.defaultModel;

          if (availableModels.contains(loadedModel)) {
            _llmModel = loadedModel;
          } else {
            _llmModel = availableModels.isNotEmpty
                ? availableModels.first
                : AppConfig.defaultModel;
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Model "$loadedModel" not found for provider $_selectedProvider.\n'
                  'Defaulting to $_llmModel.',
                ),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          });

          _temperature =
              (settings['temperature'] as num?)?.toDouble() ??
              AppConfig.defaultTemperature;
          _maxTokens =
              _modelMaxTokenLimits[_llmModel] ?? AppConfig.defaultMaxTokens;
        });

        print('⚙️ Settings loaded: $_llmModel, $_temperature, $_maxTokens');

        final secrets = settings['secrets'] as Map<String, dynamic>?;
        if (secrets != null) {
          _secretsController.text = json.encode(secrets);
          print('🔐 Loaded secrets');
        }
      }

      setState(() {
        _selectedProvider = _availableProviders.firstWhere(
          (p) =>
              p.toLowerCase() ==
              (agentConfig['modelProvider'] ?? '').toLowerCase(),
          orElse: () => AppConfig.defaultModelProvider,
        );
      });
      print('🌐 Provider selected: $_selectedProvider');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agent configuration loaded from file!')),
      );
    } catch (e) {
      print('❌ Failed to load or parse agent file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load file: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Creating agent...',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GradientButton(
                onPressed: _isLoading ? null : _loadAgentConfigFromFile,
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
                height: 56,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Load from JSON File',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
              const SizedBox(height: 24),
              _buildAgentDetailsSection(),
              const SizedBox(height: 24),
              _buildLLMSettingsSection(),
              const SizedBox(height: 24),
              _buildCreateButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgentDetailsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Agent Details',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _nameController,
              label: 'Agent Name',
              prefixIcon: Icons.person,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an agent name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _systemController,
              label: 'System Prompt',
              prefixIcon: Icons.psychology,
              maxLines: 4,
              hintText: 'Define your agent\'s personality and behavior...',
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _bioController,
              label: 'Bio (comma-separated)',
              prefixIcon: Icons.info_outline,
              maxLines: 4,
              hintText:
                  'e.g., "I am an expert in travel, I can provide detailed itineraries."',
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _loreController,
              label: 'Lore (comma-separated)',
              prefixIcon: Icons.menu_book,
              maxLines: 4,
              hintText: 'e.g., "Born from ancient maps, explorer."',
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _knowledgeAreasController,
              label: 'Knowledge Areas (comma-separated)',
              prefixIcon: Icons.lightbulb_outline,
              maxLines: 4,
              hintText: 'e.g., "travel, history, geography, cuisine"',
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _messageExamplesController,
              label: 'Message Examples (JSON Array)',
              prefixIcon: Icons.message,
              maxLines: 6,
              hintText: '[{"user": "[user1]", "content": "hello"}]',
              validator: (value) {
                if (value == null || value.isEmpty) return null;
                try {
                  json.decode(value);
                } catch (e) {
                  return 'Invalid JSON array';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _styleController,
              label: 'Style (JSON Object)',
              prefixIcon: Icons.brush,
              maxLines: 4,
              hintText:
                  '{"all": ["Speaks in a friendly tone.", "Uses simple language."]}',
              validator: (value) {
                if (value == null || value.isEmpty) return null;
                try {
                  json.decode(value);
                } catch (e) {
                  return 'Invalid JSON object';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLLMSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LLM Settings',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedProvider,
              decoration: const InputDecoration(
                labelText: 'LLM Provider',
                prefixIcon: Icon(Icons.cloud),
              ),
              items: _availableProviders.map((provider) {
                return DropdownMenuItem(value: provider, child: Text(provider));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedProvider = value!;
                  _updateModelAndTokenLimits(_selectedProvider);
                });
              },
            ),

            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value:
                  (_providerModels[_selectedProvider.toLowerCase()] ?? [])
                      .contains(_llmModel)
                  ? _llmModel
                  : null,
              decoration: const InputDecoration(
                labelText: 'LLM Model',
                prefixIcon: Icon(Icons.settings),
              ),
              items: (_providerModels[_selectedProvider.toLowerCase()] ?? [])
                  .map(
                    (model) =>
                        DropdownMenuItem(value: model, child: Text(model)),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _llmModel = value!;
                  _maxTokens =
                      _modelMaxTokenLimits[_llmModel] ??
                      AppConfig.defaultMaxTokens;
                });
              },
            ),

            const SizedBox(height: 16),
            CustomTextField(
              controller: _secretsController,
              label: 'Secrets (JSON)',
              prefixIcon: Icons.key,
              obscureText: false,
              maxLines: 6,
              hintText: '{"groq_api_key": "gsk_..."}',
              validator: (value) {
                if (value == null || value.isEmpty) return null;
                try {
                  json.decode(value);
                } catch (e) {
                  return 'Invalid JSON object';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Temperature: ${_temperature.toStringAsFixed(1)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Slider(
              value: _temperature,
              min: 0.0,
              max: 2.0,
              divisions: 20,
              onChanged: (value) {
                setState(() {
                  _temperature = value;
                });
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Max Tokens: $_maxTokens',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Slider(
              value: _maxTokens.toDouble(),
              min: 100,
              max: (_modelMaxTokenLimits[_llmModel]?.toDouble() ?? 32768),
              divisions: 50,
              onChanged: (value) {
                setState(() {
                  _maxTokens = value.round();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    return GradientButton(
      onPressed: _isLoading ? null : _createAgentFromForm,
      gradient: LinearGradient(
        colors: [
          Theme.of(context).colorScheme.primary,
          Theme.of(context).colorScheme.secondary,
        ],
      ),
      height: 56,
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Text(
              'Create Agent',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
    );
  }
}
