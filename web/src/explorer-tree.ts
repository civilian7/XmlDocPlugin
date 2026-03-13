import type { TreeElementInfo, DocElementKind } from './types';

// ────────────────────────────────────────────
// Tree Node
// ────────────────────────────────────────────
interface TreeNode {
  label: string;
  element: TreeElementInfo | null;
  children: TreeNode[];
  expanded: boolean;
}

export type TreeSelectionCallback = (element: TreeElementInfo) => void;
export type TreeDblClickCallback = (element: TreeElementInfo) => void;

let selectedLi: HTMLElement | null = null;
let onSelect: TreeSelectionCallback | null = null;
let onDblClick: TreeDblClickCallback | null = null;
let treeContainer: HTMLElement | null = null;
let rootNode: TreeNode | null = null;

const TYPE_KINDS: DocElementKind[] = ['class', 'record', 'interface'];
const MEMBER_KINDS: DocElementKind[] = ['method', 'property', 'field'];

// ────────────────────────────────────────────
// Build hierarchy from flat array
// ────────────────────────────────────────────
function buildTree(fileName: string, elements: TreeElementInfo[]): TreeNode {
  const root: TreeNode = {
    label: fileName.replace(/\.pas$/i, ''),
    element: null,
    children: [],
    expanded: true,
  };

  const typeMap = new Map<string, TreeNode>();

  for (const el of elements) {
    // 이름 없는 요소 건너뛰기
    if (!el.name) continue;

    const node: TreeNode = {
      label: el.name,
      element: el,
      children: [],
      expanded: true,
    };

    if (TYPE_KINDS.includes(el.kind)) {
      root.children.push(node);
      typeMap.set(el.name, node);
    } else if (MEMBER_KINDS.includes(el.kind) && el.qualifiedParent) {
      const parent = typeMap.get(el.qualifiedParent);
      if (parent) {
        parent.children.push(node);
      } else {
        root.children.push(node);
      }
    } else {
      root.children.push(node);
    }
  }

  // 각 컨테이너의 자식을 알파벳순 정렬
  // 프로퍼티: 이벤트(On* 접두어)는 일반 프로퍼티 뒤에 배치
  const isEventProp = (n: TreeNode): boolean =>
    n.element?.kind === 'property' && /^On[A-Z]/.test(n.label);

  const sortChildren = (node: TreeNode): void => {
    node.children.sort((a, b) => {
      const aEvent = isEventProp(a) ? 1 : 0;
      const bEvent = isEventProp(b) ? 1 : 0;
      if (aEvent !== bEvent) return aEvent - bEvent;
      return a.label.localeCompare(b.label, undefined, { sensitivity: 'base' });
    });
    for (const child of node.children) {
      sortChildren(child);
    }
  };
  sortChildren(root);

  return root;
}

// ────────────────────────────────────────────
// Render
// ────────────────────────────────────────────
function kindIcon(kind: DocElementKind): string {
  switch (kind) {
    case 'class':     return '<span class="tree-icon tree-icon-class">C</span>';
    case 'record':    return '<span class="tree-icon tree-icon-record">R</span>';
    case 'interface': return '<span class="tree-icon tree-icon-intf">I</span>';
    case 'method':    return '<span class="tree-icon tree-icon-method">M</span>';
    case 'property':  return '<span class="tree-icon tree-icon-prop">P</span>';
    case 'field':     return '<span class="tree-icon tree-icon-field">F</span>';
    case 'constant':  return '<span class="tree-icon tree-icon-const">K</span>';
    case 'type':      return '<span class="tree-icon tree-icon-type">T</span>';
    default:          return '<span class="tree-icon">·</span>';
  }
}

function hasDoc(el: TreeElementInfo): boolean {
  if (!el.doc) return false;
  const s = el.doc.summary ?? '';
  return s.length > 0 && !s.startsWith('TODO:');
}

// ────────────────────────────────────────────
// Expand / Collapse helpers
// ────────────────────────────────────────────
function setExpandedAll(node: TreeNode, expanded: boolean): void {
  if (node.children.length > 0) {
    node.expanded = expanded;
  }
  for (const child of node.children) {
    setExpandedAll(child, expanded);
  }
}

function setExpandedSubtree(node: TreeNode, expanded: boolean): void {
  node.expanded = expanded;
  for (const child of node.children) {
    if (child.children.length > 0) {
      setExpandedSubtree(child, expanded);
    }
  }
}

function refreshTreeDOM(container: HTMLElement): void {
  if (!rootNode) return;
  // 선택 상태 기억
  const prevSelected = selectedLi?.querySelector('.tree-label')?.textContent ?? null;
  container.innerHTML = '';
  const ul = document.createElement('ul');
  ul.className = 'tree-root';
  ul.appendChild(renderNode(rootNode));
  container.appendChild(ul);

  // 선택 복원
  if (prevSelected) {
    const rows = container.querySelectorAll<HTMLElement>('.tree-row');
    for (const row of rows) {
      const lbl = row.querySelector('.tree-label');
      if (lbl && lbl.textContent === prevSelected) {
        row.classList.add('tree-selected');
        selectedLi = row;
        break;
      }
    }
  }
}

// ────────────────────────────────────────────
// Context menu
// ────────────────────────────────────────────
let activeContextMenu: HTMLElement | null = null;

function removeContextMenu(): void {
  if (activeContextMenu) {
    activeContextMenu.remove();
    activeContextMenu = null;
  }
}

function showContextMenu(e: MouseEvent, node: TreeNode): void {
  e.preventDefault();
  e.stopPropagation();
  removeContextMenu();

  const menu = document.createElement('div');
  menu.className = 'tree-context-menu';

  const items: { label: string; action: () => void }[] = [];

  // 컨테이너 노드인 경우 펼치기/접기 항목
  if (node.children.length > 0) {
    items.push({
      label: node.expanded ? 'Collapse' : 'Expand',
      action: () => {
        node.expanded = !node.expanded;
        refreshTreeDOM(treeContainer!);
      },
    });
  }

  items.push({
    label: 'Expand All',
    action: () => {
      if (rootNode) setExpandedAll(rootNode, true);
      refreshTreeDOM(treeContainer!);
    },
  });

  items.push({
    label: 'Collapse All',
    action: () => {
      if (rootNode) setExpandedAll(rootNode, false);
      refreshTreeDOM(treeContainer!);
    },
  });

  for (const item of items) {
    const div = document.createElement('div');
    div.className = 'tree-context-item';
    div.textContent = item.label;
    div.addEventListener('click', (ev) => {
      ev.stopPropagation();
      removeContextMenu();
      item.action();
    });
    menu.appendChild(div);
  }

  document.body.appendChild(menu);
  activeContextMenu = menu;

  // 위치 조정 (화면 밖으로 넘어가지 않도록)
  const menuRect = menu.getBoundingClientRect();
  let x = e.clientX;
  let y = e.clientY;
  if (x + menuRect.width > window.innerWidth) x = window.innerWidth - menuRect.width - 4;
  if (y + menuRect.height > window.innerHeight) y = window.innerHeight - menuRect.height - 4;
  menu.style.left = x + 'px';
  menu.style.top = y + 'px';
}

// 클릭으로 컨텍스트 메뉴 닫기
document.addEventListener('click', removeContextMenu);
document.addEventListener('contextmenu', () => removeContextMenu());

// ────────────────────────────────────────────
// Render node
// ────────────────────────────────────────────
function renderNode(node: TreeNode): HTMLLIElement {
  const li = document.createElement('li');
  li.className = 'tree-node';

  const row = document.createElement('div');
  row.className = 'tree-row';

  const isContainer = node.children.length > 0;

  // Expand/collapse arrow
  const arrow = document.createElement('span');
  arrow.className = 'tree-arrow';
  if (isContainer) {
    arrow.textContent = node.expanded ? '▾' : '▸';
    arrow.classList.add('tree-arrow-active');
  }
  row.appendChild(arrow);

  // Icon
  if (node.element) {
    row.insertAdjacentHTML('beforeend', kindIcon(node.element.kind));
  } else {
    row.insertAdjacentHTML('beforeend', '<span class="tree-icon tree-icon-unit">U</span>');
  }

  // Label
  const label = document.createElement('span');
  label.className = 'tree-label';
  label.textContent = node.label;
  row.appendChild(label);

  // Doc status dot
  if (node.element) {
    const dot = document.createElement('span');
    dot.className = hasDoc(node.element) ? 'tree-dot tree-dot-ok' : 'tree-dot tree-dot-none';
    row.appendChild(dot);
  }

  li.appendChild(row);

  // Children
  if (isContainer) {
    const ul = document.createElement('ul');
    ul.className = 'tree-children';
    if (!node.expanded) ul.style.display = 'none';
    for (const child of node.children) {
      ul.appendChild(renderNode(child));
    }
    li.appendChild(ul);

    // Toggle expand
    arrow.addEventListener('click', (e) => {
      e.stopPropagation();
      node.expanded = !node.expanded;
      arrow.textContent = node.expanded ? '▾' : '▸';
      ul.style.display = node.expanded ? '' : 'none';
    });
  }

  // Selection
  row.addEventListener('click', () => {
    if (selectedLi) selectedLi.classList.remove('tree-selected');
    row.classList.add('tree-selected');
    selectedLi = row;

    if (node.element && onSelect) {
      onSelect(node.element);
    }
  });

  // Double-click → jump to line
  row.addEventListener('dblclick', () => {
    if (node.element && onDblClick) {
      onDblClick(node.element);
    }
  });

  // Context menu
  row.addEventListener('contextmenu', (e) => showContextMenu(e, node));

  return li;
}

// ────────────────────────────────────────────
// Public API
// ────────────────────────────────────────────
export function initTree(
  container: HTMLElement,
  selectCb: TreeSelectionCallback,
  dblClickCb: TreeDblClickCallback,
): void {
  onSelect = selectCb;
  onDblClick = dblClickCb;
  treeContainer = container;
  container.innerHTML = '<div class="tree-empty">Open a .pas file to see the structure</div>';
}

export function populateTree(
  container: HTMLElement,
  fileName: string,
  elements: TreeElementInfo[],
): void {
  const tree = buildTree(fileName, elements);
  rootNode = tree;
  treeContainer = container;
  container.innerHTML = '';

  const ul = document.createElement('ul');
  ul.className = 'tree-root';
  ul.appendChild(renderNode(tree));
  container.appendChild(ul);
}

export function expandAll(): void {
  if (rootNode && treeContainer) {
    setExpandedAll(rootNode, true);
    refreshTreeDOM(treeContainer);
  }
}

export function collapseAll(): void {
  if (rootNode && treeContainer) {
    setExpandedAll(rootNode, false);
    refreshTreeDOM(treeContainer);
  }
}

export function selectByFullName(container: HTMLElement, fullName: string): void {
  // Clear current selection
  if (selectedLi) selectedLi.classList.remove('tree-selected');

  // Find matching row by walking all tree-row elements
  const rows = container.querySelectorAll<HTMLElement>('.tree-row');
  for (const row of rows) {
    const li = row.parentElement;
    if (!li) continue;
    // Match by label text (fullName check)
    // This is done by the caller, so we just expose the API
  }
}
