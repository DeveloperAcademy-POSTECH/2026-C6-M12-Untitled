# 2026-C6-M12-Untitled

## 1. 이슈 작성하기

✹ **Git Issue 사용법**

- 작업할 기능에 대한 issue를 작성합니다.
- issue 제목은 **[종류] 작업 명**으로 통일합니다. (ex. [Style] 온보딩 UI 구현)
- 종류는 대문자로 시작합니다. (Add, Chore, Docs, Feat, Fix, Refactor, Style, Setting, Test)
- Assignees에는 작업을 맡은 사람을 태그합니다.
- Labels에는 해당 작업과 맞는 유형을 태그합니다.
- 설명란에는 어떤 작업을 할 예정인지, 관련된 이슈번호가 있는지, 참고한 내용이 있는지 등 필요한 내용을 적습니다.
- 이렇게 issue를 생성하게 되면 #N의 이슈 번호가 생깁니다.
- **1개의 issue는 1개의 branch와 1:1로 대응합니다.**
<br />
<br />

## 2. 브랜치 만들기

✹ **Git Branch 사용법**

- 각자 생성한 브랜치에서만 작업합니다. (브랜치 생성은 Issue 사용법 참고)
- 브랜치 이름 구조는 <**종류/#이슈번호**> 입니다. (ex. feat/#3)
- 브랜치 종류는 **소문자**로 만듭니다.
- 디폴트 브랜치는 **develop**입니다.
- **main 브랜치는 건드리지 않습니다.**
<br />
<br />

## 3. checkout 해서 브랜치 변경 (중요!! 🧠🫀🧨)

```bash
git checkout feat/#3
```
<br />
<br />

## 4. 작업

- 작업합니다
- 테스크 단위로 커밋합니다
- 커밋은 잘 쪼개주세요. 너무 많은 내용을 한 번에 커밋하지 않습니다!
- pull request를 통해 본인이 작업한 branch를 develop branch에 merge합니다.
- 코드 리뷰한 후 머지하기

✹ Commit 메시지 작성법

```bash
종류: #이슈번호 설명
ex) style: #12 로그인 버튼 컴포넌트 구현
```

| type | Description | Example |
| --- | --- | --- |
| add | 파일, 에셋 추가 | add: #5 앱 아이콘 추가 |
| chore | 자잘한 코드 수정 | chore: #7 변수명 오타 수정 |
| docs | 문서 작성 및 수정 (README.md 등) | docs: #1 README 작성 |
| feat | 기능 구현 | feat: #3 곡 업로드 기능 구현 |
| fix | 버그 수정 | fix: #9 재생 위치 버그 수정 |
| refactor | 코드 리팩토링 | refactor: #11 SessionFeature 파일 분리 |
| style | UI 작업 | style: #12 로그인 버튼 컴포넌트 구현 |
| setting | 프로젝트 세팅 | setting: #2 디렉토리 구조 세팅 |
| test | 테스트 코드 작성 및 수정 | test: #14 SessionFeature 테스트 추가 |

✹ Pull Request 제목 작성법

```bash
[종류/#이슈번호] 내용
ex) [Style/#3] 온보딩 UI 구현
```

- 종류는 대문자로 시작합니다.
- Pull Request 제목은 Issue의 제목과 동일하게 작성합니다.
- Pull Request 생성 시 이슈와 연결해주세요~
- 한 번에 너무 많은 내용의 PR을 올리면 코드리뷰하기 힘듭니다. 팀원들을 배려하여 **800줄 이내**로 짭시다 😎
