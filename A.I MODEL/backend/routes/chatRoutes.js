const express = require('express');
const {
  TOOL_DEFINITIONS,
  executeWorkspaceTool,
  getWorkspaceRoot,
  requiresApproval,
} = require('../workspaceTools');

const router = express.Router();
const deepSeekUrl = 'https://api.deepseek.com/chat/completions';
const maxToolRounds = 6;

const workspaceSystemMessage = {
  role: 'system',
  content: [
    'You are DeepSeek, the AI assistant in Juveh A.I.',
    'When a workspace is active, use the provided workspace tools to inspect and modify files instead of pretending you edited them.',
    'Use relative paths only. Never ask for or use paths outside the active workspace.',
    'Before changing code, read the relevant file when needed. After a successful write or delete, clearly report what changed.',
  ].join(' '),
};

const chatSystemMessage = {
  role: 'system',
  content: [
    'You are DeepSeek, the conversational assistant in Juveh A.I.',
    'Answer the user directly and stay focused on the topic they asked about.',
    'This is a private chat with no workspace, file, or coding-tool access.',
    'Do not mention workspaces, files, tools, or editing unless the user explicitly asks about that topic.',
    'If the question is unclear, ask one concise clarifying question instead of inventing context.',
  ].join(' '),
};

async function callDeepSeek(messages, workspaceEnabled) {
  const request = {
    model: process.env.DEEPSEEK_MODEL || 'deepseek-chat',
    messages,
    temperature: workspaceEnabled ? 0.3 : 0.6,
    stream: false,
  };
  if (workspaceEnabled) {
    request.tools = TOOL_DEFINITIONS;
    request.tool_choice = 'auto';
  }

  const response = await fetch(deepSeekUrl, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${process.env.DEEPSEEK_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(request),
  });

  const data = await response.json();
  if (!response.ok) {
    console.error('DeepSeek request failed:', data);
    throw new Error('DeepSeek request failed.');
  }

  return data.choices?.[0]?.message;
}

function addAttachmentsToMessages(messages, attachments) {
  if (!Array.isArray(attachments) || attachments.length === 0) {
    return messages;
  }

  const enriched = messages.map((message) => ({ ...message }));
  const userIndex = enriched.map((message) => message.role).lastIndexOf('user');
  if (userIndex < 0) return enriched;

  const parts = [{ type: 'text', text: enriched[userIndex].content || '' }];
  for (const attachment of attachments) {
    if (attachment.kind === 'image' && typeof attachment.content === 'string') {
      parts.push({
        type: 'image_url',
        image_url: { url: attachment.content },
      });
    } else if (typeof attachment.content === 'string') {
      parts.push({
        type: 'text',
        text: `\n\nAttached file: ${attachment.name || 'file'}\n${attachment.content}`,
      });
    }
  }

  enriched[userIndex] = { ...enriched[userIndex], content: parts };
  return enriched;
}

router.post('/', async (req, res) => {
  const {
    messages,
    workspacePath,
    allowWorkspaceChanges = false,
    attachments = [],
  } = req.body;

  if (!process.env.DEEPSEEK_API_KEY) {
    return res.status(503).json({ error: 'DeepSeek API key is not configured.' });
  }

  if (!Array.isArray(messages) || messages.length === 0) {
    return res.status(400).json({ error: 'messages must be a non-empty array.' });
  }

  try {
    const workspaceEnabled = typeof workspacePath === 'string' && workspacePath.trim().length > 0;
    const conversation = [
      workspaceEnabled ? workspaceSystemMessage : chatSystemMessage,
      ...addAttachmentsToMessages(messages, attachments),
    ];
    const pendingActions = [];

    for (let round = 0; round < maxToolRounds; round += 1) {
      const assistantMessage = await callDeepSeek(conversation, workspaceEnabled);
      if (!assistantMessage) {
        return res.status(502).json({ error: 'DeepSeek returned an empty response.' });
      }

      if (!assistantMessage.tool_calls?.length) {
        return res.json({
          content: assistantMessage.content || '',
          pendingActions,
        });
      }

      conversation.push(assistantMessage);

      for (const toolCall of assistantMessage.tool_calls) {
        const name = toolCall.function?.name;
        let args;
        try {
          args = JSON.parse(toolCall.function?.arguments || '{}');
        } catch (_) {
          args = {};
        }

        if (requiresApproval(name) && !allowWorkspaceChanges) {
          pendingActions.push({
            id: toolCall.id,
            name,
            arguments: args,
          });
          continue;
        }

        let result;
        try {
          getWorkspaceRoot(workspacePath);
          result = await executeWorkspaceTool(name, args, workspacePath);
        } catch (error) {
          result = { error: error.message };
        }

        conversation.push({
          role: 'tool',
          tool_call_id: toolCall.id,
          content: JSON.stringify(result),
        });
      }

      if (pendingActions.length > 0) {
        return res.json({
          content: 'DeepSeek wants to change your workspace. Review and approve the requested operation before it runs.',
          pendingActions,
        });
      }
    }

    return res.status(502).json({ error: 'The workspace tool loop exceeded its safety limit.' });
  } catch (error) {
    console.error('Chat request failed:', error);
    res.status(502).json({ error: error.message || 'Unable to reach DeepSeek.' });
  }
});

module.exports = router;
