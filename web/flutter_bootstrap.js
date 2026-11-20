{{flutter_js}}
{{flutter_build_config}}

// Render the app into #flutter_host, which fills the viewport.
_flutter.loader.load({
  config: {
    hostElement: document.querySelector('#flutter_host'),
  },
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
