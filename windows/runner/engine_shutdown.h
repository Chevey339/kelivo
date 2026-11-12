#ifndef RUNNER_ENGINE_SHUTDOWN_H_
#define RUNNER_ENGINE_SHUTDOWN_H_

// Preparation may pump native messages. Keep the engine and every plugin alive
// until it returns, and ignore any nested attempt to destroy the same engine.
class EngineShutdown {
 public:
  template <typename Prepare, typename Destroy>
  void Run(Prepare prepare, Destroy destroy) {
    if (started_) return;
    started_ = true;
    prepare();
    destroy();
  }

  bool started() const { return started_; }

 private:
  bool started_ = false;
};

#endif  // RUNNER_ENGINE_SHUTDOWN_H_
