export const DevToolsPrompt = {
  type: 'checkbox',
  name: 'installDevTools',
  message: 'Which dev tools would you like to install?',
  choices: [
    {
      name: 'Warp',
      value: 'warp',
    },
    {
      name: 'Iterm2',
      value: 'iterm2',
    },
    {
      name: 'Hyper',
      value: 'hyper',
    },
    {
      name: 'Raycast',
      value: 'raycast',
    },
    {
      name: 'VS Code',
      value: 'visual-studio-code',
    },
    {
      name: 'Docker',
      value: 'docker',
    },
    {
      name: 'Github Desktop',
      value: 'github',
    }
  ]
};
