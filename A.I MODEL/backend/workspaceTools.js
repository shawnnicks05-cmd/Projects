const fs = require('fs/promises');
const path = require('path');

const TOOL_DEFINITIONS = [
  {
    type: 'function',
    function: {
      name: 'list_directory',
      description: 'List files and folders inside the active workspace directory.',
      parameters: {
        type: 'object',
        properties: { path: { type: 'string', description: 'Relative directory path. Use . for the workspace root.' } },
        required: ['path'],
        additionalProperties: false,
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'read_file',
      description: 'Read a UTF-8 text file inside the active workspace.',
      parameters: {
        type: 'object',
        properties: { path: { type: 'string', description: 'Relative file path inside the workspace.' } },
        required: ['path'],
        additionalProperties: false,
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'write_file',
      description: 'Create or overwrite a UTF-8 text file inside the active workspace.',
      parameters: {
        type: 'object',
        properties: {
          path: { type: 'string', description: 'Relative file path inside the workspace.' },
          content: { type: 'string', description: 'Complete UTF-8 file content.' },
        },
        required: ['path', 'content'],
        additionalProperties: false,
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'delete_file',
      description: 'Delete a file inside the active workspace.',
      parameters: {
        type: 'object',
        properties: { path: { type: 'string', description: 'Relative file path inside the workspace.' } },
        required: ['path'],
        additionalProperties: false,
      },
    },
  },
];

function getWorkspaceRoot(workspacePath) {
  if (typeof workspacePath !== 'string' || !workspacePath.trim()) {
    throw new Error('Choose a workspace folder before using workspace tools.');
  }

  const root = path.resolve(workspacePath);
  return root;
}

function resolveWorkspacePath(workspacePath, relativePath) {
  const root = getWorkspaceRoot(workspacePath);
  if (typeof relativePath !== 'string' || !relativePath.trim()) {
    throw new Error('A relative workspace path is required.');
  }

  const target = path.resolve(root, relativePath);
  const relative = path.relative(root, target);
  if (relative === '..' || relative.startsWith(`..${path.sep}`) || path.isAbsolute(relative)) {
    throw new Error('Workspace tools can only access paths inside the selected workspace.');
  }

  return { root, target };
}

async function executeWorkspaceTool(name, args, workspacePath) {
  if (name === 'list_directory') {
    const { target } = resolveWorkspacePath(workspacePath, args.path);
    const entries = await fs.readdir(target, { withFileTypes: true });
    return entries.map((entry) => ({ name: entry.name, type: entry.isDirectory() ? 'directory' : 'file' }));
  }

  if (name === 'read_file') {
    const { target } = resolveWorkspacePath(workspacePath, args.path);
    return { path: args.path, content: await fs.readFile(target, 'utf8') };
  }

  if (name === 'write_file') {
    const { target } = resolveWorkspacePath(workspacePath, args.path);
    await fs.mkdir(path.dirname(target), { recursive: true });
    await fs.writeFile(target, args.content, 'utf8');
    return { path: args.path, status: 'written' };
  }

  if (name === 'delete_file') {
    const { target } = resolveWorkspacePath(workspacePath, args.path);
    await fs.unlink(target);
    return { path: args.path, status: 'deleted' };
  }

  throw new Error(`Unknown workspace tool: ${name}`);
}

function requiresApproval(name) {
  return name === 'write_file' || name === 'delete_file';
}

module.exports = {
  TOOL_DEFINITIONS,
  executeWorkspaceTool,
  getWorkspaceRoot,
  requiresApproval,
};
