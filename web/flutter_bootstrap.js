{{flutter_js}}
{{flutter_build_config}}

// Render the app into #flutter_host instead of the whole page, so the
// bottom ad band reserves its own space and never overlaps the UI.
_flutter.loader.load({
  config: {
    hostElement: document.querySelector('#flutter_host'),
  },
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
