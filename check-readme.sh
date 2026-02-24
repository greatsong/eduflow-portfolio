#!/bin/bash
# check-readme.sh — 포트폴리오 등록 전 README 검사 및 자동 생성
#
# 사용법:
#   ./check-readme.sh                    # projects.json 전체 검사
#   ./check-readme.sh --fix              # 누락된 README 자동 생성
#   ./check-readme.sh --check-only repo  # 특정 저장소만 검사

set -euo pipefail

GITHUB_USER="greatsong"
FIX_MODE=false
TARGET_REPO=""

# 인자 파싱
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fix) FIX_MODE=true; shift ;;
    --check-only) TARGET_REPO="$2"; shift 2 ;;
    *) echo "알 수 없는 옵션: $1"; exit 1 ;;
  esac
done

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
FIXED=0

check_repo() {
  local repo=$1
  local title=$2
  local desc=$3

  # README 존재 확인
  local readme_content
  readme_content=$(gh api "repos/${GITHUB_USER}/${repo}/readme" --jq '.content' 2>/dev/null | base64 --decode 2>/dev/null || echo "")

  if [[ -z "$readme_content" ]]; then
    echo -e "  ${RED}✗ README.md 없음${NC}"

    if $FIX_MODE; then
      echo -e "  ${YELLOW}→ README.md 생성 중...${NC}"
      create_readme "$repo" "$title" "$desc"
      echo -e "  ${GREEN}✓ README.md 생성 완료${NC}"
      FIXED=$((FIXED + 1))
    else
      FAIL=$((FAIL + 1))
    fi
    return
  fi

  # 개요 섹션 확인 (## 개요 또는 첫 문단이 개요 역할)
  local has_overview=false
  if echo "$readme_content" | grep -qiE '## 개요|## Overview|## 소개'; then
    has_overview=true
  fi

  # 기여 방법 섹션 확인
  local has_contributing=false
  if echo "$readme_content" | grep -qiE '## 함께 만들어가요|## 기여|## Contributing|기여 방법|CONTRIBUTING\.md'; then
    has_contributing=true
  fi

  if $has_overview && $has_contributing; then
    echo -e "  ${GREEN}✓ 개요: 있음 | 기여 방법: 있음${NC}"
    PASS=$((PASS + 1))
  else
    local missing=""
    if ! $has_overview; then missing="개요"; fi
    if ! $has_contributing; then
      [[ -n "$missing" ]] && missing="${missing}, "
      missing="${missing}기여 방법"
    fi
    echo -e "  ${RED}✗ 누락: ${missing}${NC}"

    if $FIX_MODE; then
      echo -e "  ${YELLOW}→ README.md 재생성 중...${NC}"

      # 기존 README의 SHA 가져오기
      local sha
      sha=$(gh api "repos/${GITHUB_USER}/${repo}/readme" --jq '.sha' 2>/dev/null || echo "")

      create_readme "$repo" "$title" "$desc" "$sha"
      echo -e "  ${GREEN}✓ README.md 업데이트 완료${NC}"
      FIXED=$((FIXED + 1))
    else
      FAIL=$((FAIL + 1))
    fi
  fi
}

create_readme() {
  local repo=$1
  local title=$2
  local desc=$3
  local sha=${4:-""}

  local content="# ${title}

${desc}

**사이트 바로가기**: https://greatsong.github.io/${repo}/

## 개요

이 교재는 [에듀플로](https://github.com/greatsong/data-ai-book)로 제작된 교육 자료입니다.
${desc}
모든 콘텐츠는 오픈소스로 공개되어 있으며, 누구나 자유롭게 활용하고 개선에 참여할 수 있습니다.

## 함께 만들어가요

선생님들의 참여를 환영합니다!

- **오탈자·오류 발견** — [Issues](../../issues)에 알려주세요
- **내용 개선 제안** — 더 좋은 설명이나 예시가 있다면 [Issues](../../issues) 또는 PR로 보내주세요
- **나만의 교육 자료 만들기** — [에듀플로](https://github.com/greatsong/data-ai-book)로 직접 만든 자료를 [포트폴리오](https://greatsong.github.io/eduflow-portfolio/)에 등록할 수 있습니다

### 기여 방법

1. 이 저장소를 **Fork** 합니다
2. 수정할 내용을 변경합니다
3. **Pull Request**를 보내주세요

> 📜 라이선스: CC BY-NC-SA 4.0 (비상업적, 동일조건 변경허락)

## ✨ 기여자 (Contributors)

이 교재를 함께 만들어가는 분들입니다.

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<table>
  <tbody>
    <tr>
      <td align=\"center\" valign=\"top\" width=\"14.28%\"><a href=\"https://github.com/greatsong\"><img src=\"https://github.com/greatsong.png?s=80\" width=\"80px;\" alt=\"석리송\"/><br /><sub><b>석리송</b></sub></a><br />📖 콘텐츠 · 🔧 관리</td>
    </tr>
  </tbody>
</table>
<!-- ALL-CONTRIBUTORS-LIST:END -->

> 💡 기여해주시면 여기에 자동으로 프로필이 추가됩니다!
> Issue 댓글에 \`@all-contributors please add @사용자명 for content\` 라고 남겨주세요.

---

Made with [에듀플로](https://github.com/greatsong/data-ai-book)"

  local encoded
  encoded=$(echo "$content" | base64)

  local api_args=(-X PUT -f "message=README.md 추가: 개요 및 기여 방법 포함" -f "content=${encoded}")
  if [[ -n "$sha" ]]; then
    api_args+=(-f "sha=${sha}")
  fi

  gh api "repos/${GITHUB_USER}/${repo}/contents/README.md" \
    "${api_args[@]}" \
    --jq '.content.name' > /dev/null 2>&1
}

echo ""
echo "=========================================="
echo "  에듀플로 포트폴리오 README 검사기"
echo "=========================================="
echo ""

if [[ -n "$TARGET_REPO" ]]; then
  echo "[검사] ${TARGET_REPO}"
  check_repo "$TARGET_REPO" "$TARGET_REPO" ""
else
  # projects.json에서 프로젝트 목록 읽기
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECTS_FILE="${SCRIPT_DIR}/projects.json"

  if [[ ! -f "$PROJECTS_FILE" ]]; then
    echo -e "${RED}오류: projects.json을 찾을 수 없습니다.${NC}"
    exit 1
  fi

  # jq로 프로젝트 목록 파싱
  total=$(jq length "$PROJECTS_FILE")
  echo "총 ${total}개 프로젝트 검사 시작..."
  echo ""

  for i in $(seq 0 $((total - 1))); do
    name=$(jq -r ".[$i].name" "$PROJECTS_FILE")
    title=$(jq -r ".[$i].title" "$PROJECTS_FILE")
    desc=$(jq -r ".[$i].description" "$PROJECTS_FILE")

    echo "[${i}/$((total - 1))] ${name}"
    check_repo "$name" "$title" "$desc"
    echo ""
  done
fi

echo "=========================================="
echo "  검사 결과"
echo "=========================================="
echo -e "  ${GREEN}통과: ${PASS}개${NC}"
echo -e "  ${RED}실패: ${FAIL}개${NC}"
if $FIX_MODE; then
  echo -e "  ${YELLOW}수정: ${FIXED}개${NC}"
fi
echo ""

if [[ $FAIL -gt 0 ]] && ! $FIX_MODE; then
  echo -e "${YELLOW}💡 --fix 옵션으로 누락된 README를 자동 생성할 수 있습니다.${NC}"
  echo "   ./check-readme.sh --fix"
  echo ""
  exit 1
fi
