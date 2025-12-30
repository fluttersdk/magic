/// Default View Configuration (UI Styles).
Map<String, dynamic> defaultViewConfig = {
  'view': {
    'snackbar': {
      'position': 'bottom',
      'duration': 4000,
      'style': {
        'success': 'bg-green-500 text-white p-4 rounded-lg shadow-lg',
        'error': 'bg-red-500 text-white p-4 rounded-lg shadow-lg',
        'info': 'bg-blue-500 text-white p-4 rounded-lg shadow-lg',
        'warning': 'bg-amber-500 text-white p-4 rounded-lg shadow-lg',
      },
    },
    'dialog': {
      'barrier_dismissible': true,
      'barrier_color': 'bg-black/50',
      'class': 'bg-white rounded-xl p-6 shadow-2xl w-80 max-w-md',
    },
    'loading': {
      'barrier_class': 'bg-black/50',
      'container_class': 'bg-white rounded-xl p-6 shadow-2xl',
      'spinner_class': 'text-blue-500',
      'text_class': 'text-gray-600 text-sm mt-4',
    },
    'toast': {
      'class': 'bg-gray-800 text-white px-6 py-3 rounded-full shadow-lg',
      'duration': 2000,
    },
    'confirm': {
      'container_class': 'bg-white rounded-xl p-6 shadow-2xl w-80',
      'title_class': 'text-lg font-bold text-gray-900',
      'message_class': 'text-gray-600 mt-2',
      'button_cancel_class': 'px-4 py-2 text-gray-600',
      'button_confirm_class': 'px-4 py-2 bg-blue-500 text-white rounded-lg',
      'button_danger_class': 'px-4 py-2 bg-red-500 text-white rounded-lg',
    },
  },
};
