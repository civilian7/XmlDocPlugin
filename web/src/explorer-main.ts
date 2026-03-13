import './styles.css';
import './explorer-styles.css';
import { init, loadDocument } from './editor';
import { bridge } from './bridge';
import { initTree, populateTree, expandAll, collapseAll } from './explorer-tree';
import type { TreeElementInfo } from './types';

let currentElements: TreeElementInfo[] = [];
let selectedElement: TreeElementInfo | null = null;

function handleTreeSelect(element: TreeElementInfo): void {
  selectedElement = element;
  loadDocument(element, element.doc);
}

function handleTreeDblClick(element: TreeElementInfo): void {
  if (element.lineNumber) {
    bridge.sendToHost({ type: 'jumpToLine', line: element.lineNumber });
  }
}

function handleLoadTree(data: { fileName: string; elements: TreeElementInfo[] }): void {
  const container = document.getElementById('tree-content')!;
  currentElements = data.elements;
  populateTree(container, data.fileName, data.elements);

  // 첫 번째 요소 자동 선택
  if (data.elements.length > 0) {
    handleTreeSelect(data.elements[0]);
  }
}

document.addEventListener('DOMContentLoaded', () => {
  const treeContent = document.getElementById('tree-content')!;
  initTree(treeContent, handleTreeSelect, handleTreeDblClick);

  // 에디터 초기화 (오른쪽 패널)
  init();

  // Explorer 전용 bridge 확장: loadTree 메시지 처리
  const originalReceive = bridge.receive.bind(bridge);
  bridge.receive = (message: any) => {
    if (message.type === 'loadTree') {
      handleLoadTree(message.data);
    } else {
      originalReceive(message);
    }
  };

  // docUpdated 가로채기: elementFullName 추가
  const originalSendToHost = bridge.sendToHost.bind(bridge);
  bridge.sendToHost = (message: any) => {
    if (message.type === 'docUpdated' && selectedElement) {
      message.elementFullName = selectedElement.fullName;

      // 로컬 캐시도 갱신
      selectedElement.doc = message.doc;
    }
    originalSendToHost(message);
  };

  // 헤더 펼치기/접기 버튼
  document.getElementById('btn-expand-all')?.addEventListener('click', expandAll);
  document.getElementById('btn-collapse-all')?.addEventListener('click', collapseAll);

  // 스플리터 드래그
  setupSplitter();
});

function setupSplitter(): void {
  const splitter = document.getElementById('explorer-splitter');
  const treePanel = document.getElementById('tree-panel');
  if (!splitter || !treePanel) return;

  let dragging = false;
  let startX = 0;
  let startWidth = 0;

  splitter.addEventListener('mousedown', (e) => {
    dragging = true;
    startX = e.clientX;
    startWidth = treePanel.offsetWidth;
    document.body.style.cursor = 'col-resize';
    document.body.style.userSelect = 'none';
    e.preventDefault();
  });

  document.addEventListener('mousemove', (e) => {
    if (!dragging) return;
    const dx = e.clientX - startX;
    const newWidth = Math.max(150, Math.min(600, startWidth + dx));
    treePanel.style.width = newWidth + 'px';
  });

  document.addEventListener('mouseup', () => {
    if (!dragging) return;
    dragging = false;
    document.body.style.cursor = '';
    document.body.style.userSelect = '';
  });
}
