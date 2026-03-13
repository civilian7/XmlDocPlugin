// ────────────────────────────────────────────
// Help Modal — XML Doc Tag Reference
// ────────────────────────────────────────────

interface TagInfo {
  tag: string;
  shortcut?: string;
  description: string;
  example: string;
  usage: string;
}

const TAGS: TagInfo[] = [
  {
    tag: '<summary>',
    description: 'A brief summary description of the element. Required for all documented elements.',
    example: '/// <summary>Updates user information.</summary>',
    usage: 'Write for all public types, methods, properties, and fields.',
  },
  {
    tag: '<remarks>',
    description: 'Detailed supplementary information beyond the summary. Use for implementation details and caveats.',
    example: '/// <remarks>This method is not thread-safe.</remarks>',
    usage: 'Write when there are complex behaviors or usage caveats.',
  },
  {
    tag: '<param>',
    description: 'Description of a method parameter.',
    example: '/// <param name="AUserId">The target user ID</param>',
    usage: 'Write one for each parameter of the method.',
  },
  {
    tag: '<returns>',
    description: 'Description of the method return value.',
    example: '/// <returns>Whether the update was successful</returns>',
    usage: 'Write only for functions (methods that return a value).',
  },
  {
    tag: '<value>',
    description: 'Description of a property value.',
    example: '/// <value>The number of currently active users</value>',
    usage: 'Write for properties. Similar to <returns>.',
  },
  {
    tag: '<para>',
    description: 'Paragraph separator. Used inside summary, remarks, etc. to divide content into paragraphs.',
    example: '/// <remarks>\n/// <para>First paragraph.</para>\n/// <para>Second paragraph.</para>\n/// </remarks>',
    usage: 'Use to break long descriptions into logical paragraphs.',
  },
  {
    tag: '<c>',
    shortcut: 'Ctrl+E',
    description: 'Inline code. Highlights code elements within text.',
    example: '/// <summary>Passing <c>nil</c> raises an exception.</summary>',
    usage: 'Use when mentioning variable names, values, or short code snippets.',
  },
  {
    tag: '<code>',
    description: 'Multi-line code block.',
    example: '/// <example>\n/// <code>\n/// var LUser := TUser.Create;\n/// LUser.Name := \'John\';\n/// </code>\n/// </example>',
    usage: 'Use inside <example> to show code samples.',
  },
  {
    tag: '<see cref>',
    description: 'Inline reference link to another type or member.',
    example: '/// <summary>Returns a <see cref="TUser"/>.</summary>',
    usage: 'Use when referencing other classes, methods, or properties.',
  },
  {
    tag: '<paramref>',
    description: 'Inline reference to a parameter name.',
    example: '/// <summary>Finds the user matching <paramref name="AUserId"/>.</summary>',
    usage: 'Use when mentioning a parameter within description text.',
  },
  {
    tag: '<typeparamref>',
    description: 'Inline reference to a generic type parameter.',
    example: '/// <summary>Creates an instance of <typeparamref name="T"/>.</summary>',
    usage: 'Use when mentioning a generic type parameter.',
  },
  {
    tag: '<exception>',
    description: 'Documents exceptions that a method may throw.',
    example: '/// <exception cref="EArgumentNilException">When AUser is nil</exception>',
    usage: 'Write one for each exception type the method can raise.',
  },
  {
    tag: '<example>',
    description: 'Contains a code usage example.',
    example: '/// <example>\n/// <code>LResult := Calculator.Add(1, 2);</code>\n/// </example>',
    usage: 'Write to demonstrate usage with code.',
  },
  {
    tag: '<seealso>',
    description: 'A reference displayed in the "See Also" section of the help topic.',
    example: '/// <seealso cref="TUserManager.DeleteUser"/>',
    usage: 'Use to link related APIs. Unlike <see>, this appears in a separate section.',
  },
];

let modalEl: HTMLElement | null = null;

function createModal(): HTMLElement {
  const overlay = document.createElement('div');
  overlay.className = 'help-modal-overlay';

  const modal = document.createElement('div');
  modal.className = 'help-modal';

  const header = document.createElement('div');
  header.className = 'help-modal-header';
  header.innerHTML = `
    <span class="help-modal-title">XML Doc Tag Reference</span>
    <button class="help-modal-close" title="Close">&times;</button>
  `;

  const body = document.createElement('div');
  body.className = 'help-modal-body';

  TAGS.forEach(tag => {
    const card = document.createElement('div');
    card.className = 'help-tag-card';

    const titleLine = tag.shortcut
      ? `<span class="help-tag-name">${tag.tag}</span><kbd class="help-tag-shortcut">${tag.shortcut}</kbd>`
      : `<span class="help-tag-name">${tag.tag}</span>`;

    card.innerHTML = `
      <div class="help-tag-header">${titleLine}</div>
      <p class="help-tag-desc">${tag.description}</p>
      <pre class="help-tag-example"><code>${escapeHtml(tag.example)}</code></pre>
      <p class="help-tag-usage">${tag.usage}</p>
    `;
    body.appendChild(card);
  });

  modal.appendChild(header);
  modal.appendChild(body);
  overlay.appendChild(modal);

  header.querySelector('.help-modal-close')!.addEventListener('click', hideHelpModal);
  overlay.addEventListener('click', (e) => {
    if (e.target === overlay) hideHelpModal();
  });

  return overlay;
}

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

export function showHelpModal(): void {
  if (modalEl) return;
  modalEl = createModal();
  document.body.appendChild(modalEl);

  const onKeyDown = (e: KeyboardEvent) => {
    if (e.key === 'Escape') hideHelpModal();
  };
  document.addEventListener('keydown', onKeyDown);
  (modalEl as any).__keyHandler = onKeyDown;
}

export function hideHelpModal(): void {
  if (!modalEl) return;
  const handler = (modalEl as any).__keyHandler;
  if (handler) document.removeEventListener('keydown', handler);
  modalEl.remove();
  modalEl = null;
}
