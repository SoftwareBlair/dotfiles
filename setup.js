import inquirer from 'inquirer';
import { Observable } from 'rxjs';

import { caskInstall } from './utils/utils.js';

import { DevToolsPrompt } from './prompts/DevToolsPrompt.js';
import { BrowsersPrompt } from './prompts/BrowsersPrompt.js';

const observe = Observable.create((observer) => {
  observer.next(DevToolsPrompt);

  observer.next(BrowsersPrompt);

  observer.complete();
});

inquirer.prompt(observe).then((answers) => {
  if (answers.installDevTools) {
    console.log('Installing dev tools...');
    caskInstall(answers.installDevTools);
  }

  if (answers.installBrowsers) {
    console.log('Installing browsers...');
    caskInstall(answers.installBrowsers);
  }
});
