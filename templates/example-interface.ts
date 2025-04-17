#!/usr/bin/env node
// hello.ts - Simple greeting utility in TypeScript
// RC Summary: Displays a customizable greeting message (TypeScript version)

import * as yargs from 'yargs';
import { hideBin } from 'yargs/helpers';

interface Arguments {
  name?: string;
  format: string;
  uppercase: boolean;
  summary: boolean;
  version: boolean;
}

async function main(): Promise<number> {
  // Parse command line arguments
  const argv = await yargs(hideBin(process.argv))
    .scriptName('hello')
    .usage('Usage: $0 [options] [name]')
    .option('format', {
      describe: 'Greeting format',
      type: 'string',
      default: 'Hello, {name}!'
    })
    .option('uppercase', {
      alias: 'u',
      describe: 'Convert to uppercase',
      type: 'boolean',
      default: false
    })
    .option('summary', {
      describe: 'Show summary for rc help',
      type: 'boolean',
      default: false
    })
    .option('version', {
      describe: 'Show version information',
      type: 'boolean',
      default: false
    })
    .help()
    .parseAsync() as unknown as Arguments;
  
  // Handle special rc command flags
  if (argv.summary) {
    console.log('Displays a customizable greeting message (TypeScript version)');
    return 0;
  }
  
  if (argv.version) {
    console.log('hello - rcForge Utility v0.4.1');
    return 0;
  }
  
  // Main functionality
  const name = argv.name || 'Friend';
  let greeting = argv.format.replace('{name}', name);
  
  if (argv.uppercase) {
    greeting = greeting.toUpperCase();
  }
  
  console.log(greeting);
  return 0;
}

// Execute main function and handle exit code
main()
  .then(exitCode => process.exit(exitCode))
  .catch(error => {
    console.error('Error:', error);
    process.exit(1);
  });
