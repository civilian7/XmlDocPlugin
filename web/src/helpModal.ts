// ────────────────────────────────────────────
// Help Modal — XML Doc 태그 레퍼런스
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
    description: '요소의 간략한 요약 설명. 모든 문서화된 요소에 필수입니다.',
    example: '/// <summary>사용자 정보를 업데이트합니다.</summary>',
    usage: '모든 public 타입, 메서드, 프로퍼티, 필드에 반드시 작성합니다.',
  },
  {
    tag: '<remarks>',
    description: 'summary보다 상세한 추가 설명. 구현 세부사항, 주의사항 등을 기술합니다.',
    example: '/// <remarks>이 메서드는 스레드 안전하지 않습니다.</remarks>',
    usage: '복잡한 동작이나 사용 시 주의사항이 있을 때 작성합니다.',
  },
  {
    tag: '<param>',
    description: '메서드 파라미터에 대한 설명.',
    example: '/// <param name="AUserId">대상 사용자 ID</param>',
    usage: '메서드의 모든 파라미터에 대해 하나씩 작성합니다.',
  },
  {
    tag: '<returns>',
    description: '메서드의 반환값에 대한 설명.',
    example: '/// <returns>업데이트 성공 여부</returns>',
    usage: 'function(반환값이 있는 메서드)에만 작성합니다.',
  },
  {
    tag: '<value>',
    description: '프로퍼티의 값에 대한 설명.',
    example: '/// <value>현재 활성화된 사용자 수</value>',
    usage: '프로퍼티에 대해 작성합니다. <returns>와 유사합니다.',
  },
  {
    tag: '<para>',
    description: '문단 구분. summary, remarks 등 내부에서 여러 문단을 나눌 때 사용합니다.',
    example: '/// <remarks>\n/// <para>첫 번째 문단.</para>\n/// <para>두 번째 문단.</para>\n/// </remarks>',
    usage: '긴 설명을 논리적 문단으로 나눌 때 사용합니다.',
  },
  {
    tag: '<c>',
    shortcut: 'Ctrl+E',
    description: '인라인 코드. 텍스트 내에서 코드 요소를 강조 표시합니다.',
    example: '/// <summary><c>nil</c>을 전달하면 예외가 발생합니다.</summary>',
    usage: '변수명, 값, 짧은 코드 조각을 언급할 때 사용합니다.',
  },
  {
    tag: '<code>',
    description: '여러 줄의 코드 블록.',
    example: '/// <example>\n/// <code>\n/// var LUser := TUser.Create;\n/// LUser.Name := \'홍길동\';\n/// </code>\n/// </example>',
    usage: '코드 예시를 보여줄 때 <example> 안에서 사용합니다.',
  },
  {
    tag: '<see cref>',
    description: '다른 타입이나 멤버에 대한 인라인 참조 링크.',
    example: '/// <summary><see cref="TUser"/>를 반환합니다.</summary>',
    usage: '다른 클래스, 메서드, 프로퍼티 등을 참조할 때 사용합니다.',
  },
  {
    tag: '<paramref>',
    description: '파라미터 이름에 대한 인라인 참조.',
    example: '/// <summary><paramref name="AUserId"/>에 해당하는 사용자를 찾습니다.</summary>',
    usage: '설명 텍스트 내에서 파라미터를 언급할 때 사용합니다.',
  },
  {
    tag: '<typeparamref>',
    description: '제네릭 타입 파라미터에 대한 인라인 참조.',
    example: '/// <summary><typeparamref name="T"/>의 인스턴스를 생성합니다.</summary>',
    usage: '제네릭 타입 파라미터를 언급할 때 사용합니다.',
  },
  {
    tag: '<exception>',
    description: '메서드가 발생시킬 수 있는 예외를 문서화합니다.',
    example: '/// <exception cref="EArgumentNilException">AUser가 nil일 때</exception>',
    usage: '메서드에서 발생 가능한 각 예외 타입마다 하나씩 작성합니다.',
  },
  {
    tag: '<example>',
    description: '코드 사용 예시를 포함합니다.',
    example: '/// <example>\n/// <code>LResult := Calculator.Add(1, 2);</code>\n/// </example>',
    usage: '사용법을 코드로 보여줄 때 작성합니다.',
  },
  {
    tag: '<seealso>',
    description: '도움말의 "참고 항목" 섹션에 표시되는 참조.',
    example: '/// <seealso cref="TUserManager.DeleteUser"/>',
    usage: '관련 API를 안내할 때 사용합니다. <see>와 달리 별도 섹션에 표시됩니다.',
  },
  {
    tag: '<note>',
    description: '주의사항, 팁, 경고 등 강조 블록.',
    example: '/// <note type="warning">이 메서드는 더 이상 사용되지 않습니다.</note>',
    usage: '중요한 주의사항이나 팁을 강조할 때 사용합니다. type: note, warning, tip, caution',
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
    <span class="help-modal-title">XML Doc 태그 레퍼런스</span>
    <button class="help-modal-close" title="닫기">&times;</button>
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

  // 닫기 이벤트
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
