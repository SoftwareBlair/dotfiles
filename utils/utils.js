import { spawn } from 'child_process';

export const runCommand = (command, args = []) => {
  return new Promise((resolve, reject) => {
    const childProcess = spawn(command, args, { shell: true });

    childProcess.stdout.on('data', (data) => {
      console.log(`${data}`);
    });

    childProcess.stderr.on('data', (data) => {
      console.error(`${data}`);
    });

    childProcess.on('close', (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(`Command failed with code ${code}`);
      }
    });
  });
};

export const caskInstall = (answers) => {
  const allAnswers = answers.join(' ');
  runCommand(`brew install --cask ${allAnswers}`);
};
