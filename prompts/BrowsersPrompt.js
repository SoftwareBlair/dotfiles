export const BrowsersPrompt = {
  type: 'checkbox',
  name: 'installBrowsers',
  message: 'Which browsers would you like to install?',
  choices: [
    {
      name: 'Chrome',
      value: 'google-chrome',
    },
    {
      name: 'Firefox',
      value: 'firefox',
    },
    {
      name: 'Arc',
      value: 'arc',
    },
    {
      name: 'Brave',
      value: 'brave-browser',
    },
    {
      name: 'Edge',
      value: 'microsoft-edge',
    },
    {
      name: 'Opera',
      value: 'opera',
    },
    {
      name: 'Polypane',
      value: 'polypane',
    },
    {
      name: 'Tor',
      value: 'tor',
    },
  ]
};
