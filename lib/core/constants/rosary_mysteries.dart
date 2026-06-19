/// 묵주기도 신비 — 요일별 세트 + 오늘의 묵상 인덱스.
class RosaryMystery {
  final String title;
  final String scripture;
  final String meditation;

  const RosaryMystery({
    required this.title,
    required this.scripture,
    required this.meditation,
  });
}

class RosaryMysterySet {
  final String name;
  final String subtitle;
  final String themeColor; // for reference only — UI picks Color
  final List<RosaryMystery> mysteries;

  const RosaryMysterySet({
    required this.name,
    required this.subtitle,
    required this.themeColor,
    required this.mysteries,
  });
}

RosaryMysterySet mysterySetForWeekday(int weekday) {
  // DateTime.weekday: Mon=1 … Sun=7
  return switch (weekday) {
    DateTime.monday || DateTime.saturday => _joyful,
    DateTime.tuesday || DateTime.friday => _sorrowful,
    DateTime.wednesday || DateTime.sunday => _glorious,
    DateTime.thursday => _luminous,
    _ => _joyful,
  };
}

/// 오늘 묵상할 신비 (같은 세트 안에서 날짜로 순환).
RosaryMystery todayMystery(DateTime date) {
  final set = mysterySetForWeekday(date.weekday);
  final index = (date.difference(DateTime(date.year, 1, 1)).inDays) % 5;
  return set.mysteries[index];
}

int todayMysteryIndex(DateTime date) =>
    date.difference(DateTime(date.year, 1, 1)).inDays % 5;

const _joyful = RosaryMysterySet(
  name: '환희의 신비',
  subtitle: '기쁨과 감사의 묵상',
  themeColor: 'joyful',
  mysteries: [
    RosaryMystery(
      title: '천사의 전언',
      scripture: '루카 1, 26-38',
      meditation:
          '성모 마리아께서 하느님의 뜻을 겸손히 받아들이신 순간을 묵상합니다. '
          '오늘도 주님의 초대에 “fiat(그렇게 하시옵소서)”로 응해 봅시다.',
    ),
    RosaryMystery(
      title: '엘리사벳 방문',
      scripture: '루카 1, 39-56',
      meditation:
          '“내 영혼이 주님을 찬송하며, 내 마음이 내 구주 안에서 기뻐 떨치네.” '
          '이웃을 찾아가는 사랑과 기쁨을 나누는 마음을 기릅니다.',
    ),
    RosaryMystery(
      title: '예수님의 탄생',
      scripture: '루카 2, 1-20',
      meditation:
          '겸손한 구유에서 태어나신 주님. 고요한 밤, 목자들에게 전해진 기쁜 소식처럼 '
          '오늘 하루에도 평화를 전하는 사람이 되어 봅시다.',
    ),
    RosaryMystery(
      title: '성전 봉헌',
      scripture: '루카 2, 22-38',
      meditation:
          '시므온과 안나의 눈으로 주님을 바라보듯, 일상 속 작은 순간에서도 '
          '하느님의 임재를 발견해 봅시다.',
    ),
    RosaryMystery(
      title: '성전에서 찾으신 예수님',
      scripture: '루카 2, 41-52',
      meditation:
          '“왜 저를 찾으셨나요?” — 아버지 일을 하는 예수님. '
          '우리도 오늘 하루를 하느님 뜻 안에서 살아가기를 구합니다.',
    ),
  ],
);

const _sorrowful = RosaryMysterySet(
  name: '고통의 신비',
  subtitle: '사랑과 헌신의 묵상',
  themeColor: 'sorrowful',
  mysteries: [
    RosaryMystery(
      title: '겟세마니의 기도',
      scripture: '마태 26, 36-46',
      meditation:
          '“내 마음은 슬픔에 죽게 되었으니, 깨어 있어 함께 기도합시다.” '
          '고통 앞에서도 하느님과 동행하는 기도의 힘을 묵상합니다.',
    ),
    RosaryMystery(
      title: '채찍에 맞으심',
      scripture: '요한 19, 1',
      meditation:
          '고통을 받으시며도 사랑을 포기하지 않으신 주님. '
          '오늘 겪는 작은 고난도 사랑 안에 봉헌해 봅시다.',
    ),
    RosaryMystery(
      title: '가시관 쓰심',
      scripture: '마태 27, 27-31',
      meditation:
          '조롱과 고통 속에서도 참으신 주님. '
          '우리도 받은 상처를 치유하며, 타인을 판단하지 않는 마음을 구합니다.',
    ),
    RosaryMystery(
      title: '십자가를 지심',
      scripture: '요한 19, 17',
      meditation:
          '우리 죄를 대신 짊어지신 사랑. '
          '오늘의 짐을 주님께 맡기고, 이웃의 짐을 함께 나누어 봅시다.',
    ),
    RosaryMystery(
      title: '십자가상에서 돌아가심',
      scripture: '요한 19, 25-30',
      meditation:
          '“다 이루어졌다.” — 완성된 사랑. '
          '하루의 끝, 모든 것을 하느님께 맡기는 신뢰를 기릅니다.',
    ),
  ],
);

const _glorious = RosaryMysterySet(
  name: '영광의 신비',
  subtitle: '부활과 희망의 묵상',
  themeColor: 'glorious',
  mysteries: [
    RosaryMystery(
      title: '부활',
      scripture: '요한 20, 1-18',
      meditation:
          '무덤이 비어 있음 — 죽음을 이기신 주님. '
          '오늘도 절망 너머의 희망을 품고 살아갑니다.',
    ),
    RosaryMystery(
      title: '승천',
      scripture: '마태 28, 16-20',
      meditation:
          '“내가 세상 끝날까지 너희와 함께 있겠다.” '
          '혼자가 아님을 기억하며 하루를 시작합니다.',
    ),
    RosaryMystery(
      title: '성령 강림',
      scripture: '사도 2, 1-4',
      meditation:
          '불과 같은 성령, 담대한 증거. '
          '오늘 필요한 용기와 지혜를 성렘께 구합니다.',
    ),
    RosaryMystery(
      title: '성모 승천',
      scripture: '루카 1, 46-55',
      meditation:
          '찬미와 감사로 하느님을 높이신 성모님. '
          '작은 일상 속에서도 감사의 기도를 이어갑니다.',
    ),
    RosaryMystery(
      title: '성모 대관',
      scripture: '요한 19, 25-27',
      meditation:
          '모든 성도의 어머니 되신 성모님. '
          '오늘 하루, 성모님의 중보 아래 우리 가족과 이웃을 봉헌합니다.',
    ),
  ],
);

const _luminous = RosaryMysterySet(
  name: '빛의 신비',
  subtitle: '공개와 소명의 묵상',
  themeColor: 'luminous',
  mysteries: [
    RosaryMystery(
      title: '세례',
      scripture: '마태 3, 13-17',
      meditation:
          '“이는 내 사랑하는 아들.” — 하느님의 사랑 안에서 우리 정체성을 묵상합니다.',
    ),
    RosaryMystery(
      title: '가나 혼잔',
      scripture: '요한 2, 1-12',
      meditation:
          '필요한 이들의 간구에 응하신 주님. '
          '오늘도 이웃의 필요에 관심을 기울여 봅시다.',
    ),
    RosaryMystery(
      title: '하느님 나라 선포',
      scripture: '마르코 1, 14-15',
      meditation:
          '“회개하고 복음을 믿으라.” '
          '하루를 새로 시작하는 회개와 소망을 품습니다.',
    ),
    RosaryMystery(
      title: '거룩한 변모',
      scripture: '마태 17, 1-9',
      meditation:
          '빛 가운데 드러나신 주님의 영광. '
          '어두운 순간에도 빛을 잃지 않도록 믿음을 구합니다.',
    ),
    RosaryMystery(
      title: '마지막 만찬',
      scripture: '마태 26, 26-28',
      meditation:
          '사랑의 성찬, 우리와 함께 하시는 주님. '
          '나눔과 섬김으로 그 사랑을 이어갑니다.',
    ),
  ],
);

String weekdayLabelKo(int weekday) => switch (weekday) {
  DateTime.monday => '월요일',
  DateTime.tuesday => '화요일',
  DateTime.wednesday => '수요일',
  DateTime.thursday => '목요일',
  DateTime.friday => '금요일',
  DateTime.saturday => '토요일',
  DateTime.sunday => '일요일',
  _ => '',
};
