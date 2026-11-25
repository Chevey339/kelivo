const modelScopeCreationModels = [
  'Qwen/Qwen-Image',
  'Qwen/Qwen-Image-Edit',
  'Qwen/Qwen-Image-Edit-2509',
  'Qwen/Qwen-Image-Edit-2511',
  'Qwen/Qwen-Image-2.1',
  'Qwen/Qwen-Image-2.1-Turbo',
  'MiniMax/MiniMax-H3',
  'Lightricks/LTX-2.3',
];

bool isModelScopeInferenceHost(String? host) =>
    host == 'api-inference.modelscope.cn';
