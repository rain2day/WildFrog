const featuredMountains = [
  {
    id: "tai-mo-shan",
    nameZh: "大帽山",
    nameEn: "Tai Mo Shan",
    region: "New Territories",
    regionZh: "新界",
    height: 957,
    image: "./assets/tai-mo-shan.png",
    myCheckins: 12,
    rank: 18,
    nextRankDistance: 2,
    totalCheckins: 1245,
    sourceRank: 1,
    lastZh: "今日",
    lastEn: "Today",
    coordinates: "22.411, 114.123",
  },
  {
    id: "lion-rock",
    nameZh: "獅子山",
    nameEn: "Lion Rock",
    region: "Kowloon",
    regionZh: "九龍",
    height: 495,
    image: "./assets/lion-rock.png",
    myCheckins: 8,
    rank: 32,
    nextRankDistance: 4,
    totalCheckins: 2341,
    sourceRank: 48,
    lastZh: "本週",
    lastEn: "This week",
    coordinates: "22.352, 114.187",
  },
  {
    id: "lantau-peak",
    nameZh: "鳳凰山",
    nameEn: "Lantau Peak",
    region: "Lantau",
    regionZh: "大嶼山",
    height: 934,
    image: "./assets/lantau-peak.png",
    myCheckins: 7,
    rank: 27,
    nextRankDistance: 3,
    totalCheckins: 987,
    sourceRank: 2,
    lastZh: "昨日",
    lastEn: "Yesterday",
    coordinates: "22.249, 113.921",
  },
  {
    id: "sunset-peak",
    nameZh: "大東山",
    nameEn: "Sunset Peak",
    region: "Lantau",
    regionZh: "大嶼山",
    height: 869,
    image: "./assets/lantau-peak.png",
    myCheckins: 6,
    rank: 41,
    nextRankDistance: 5,
    totalCheckins: 612,
    sourceRank: 3,
    lastZh: "本月",
    lastEn: "This month",
    coordinates: "22.263, 113.950",
  },
];

const importedMountainImages = ["./assets/tai-mo-shan.png", "./assets/lion-rock.png", "./assets/lantau-peak.png"];
const timHikingSource = {
  zh: "TimHiking 全港300+山峰",
  en: "TimHiking Hong Kong 300+ Peaks",
  url: "https://timhiking.com/hk/routebytop.php",
};

const timHikingPeaks = [
  { nameZh: "大帽山", height: 957, sourceRank: 1 },
  { nameZh: "鳳凰山", height: 934, sourceRank: 2 },
  { nameZh: "大東山", height: 869, sourceRank: 3 },
  { nameZh: "四方山", height: 785, sourceRank: 4 },
  { nameZh: "禾秧山", height: 771, sourceRank: 5 },
  { nameZh: "蓮花山(大嶼山)", height: 766, sourceRank: 6 },
  { nameZh: "妙高台", height: 765, sourceRank: 7 },
  { nameZh: "彌勒山", height: 751, sourceRank: 8 },
  { nameZh: "二東山", height: 749, sourceRank: 9 },
  { nameZh: "三山台", height: 721, sourceRank: 10 },
  { nameZh: "鴨腳瀝", height: 721, sourceRank: null },
  { nameZh: "馬鞍山", height: 702, sourceRank: 11 },
  { nameZh: "禾塘崗(主峰)", height: 702, sourceRank: 12 },
  { nameZh: "燕岩頂", height: 679, sourceRank: null },
  { nameZh: "牛押山", height: 677, sourceRank: 13 },
  { nameZh: "禾塘崗(副峰)", height: 654, sourceRank: null },
  { nameZh: "草山", height: 647, sourceRank: 14 },
  { nameZh: "牛塘山", height: 641, sourceRank: null },
  { nameZh: "黃嶺", height: 639, sourceRank: 15 },
  { nameZh: "水牛山", height: 606, sourceRank: 16 },
  { nameZh: "黃牛山", height: 604, sourceRank: 17 },
  { nameZh: "飛鵝山", height: 603, sourceRank: 18 },
  { nameZh: "彎曲山", height: 592, sourceRank: null },
  { nameZh: "純陽峰", height: 590, sourceRank: 19 },
  { nameZh: "吊手岩", height: 588, sourceRank: 20 },
  { nameZh: "走馬崗", height: 588, sourceRank: null },
  { nameZh: "象山(馬鞍山)", height: 585, sourceRank: 21 },
  { nameZh: "羅天頂", height: 585, sourceRank: 22 },
  { nameZh: "青山", height: 583, sourceRank: 23 },
  { nameZh: "蓮花山(大欖)", height: 579, sourceRank: 24 },
  { nameZh: "大老山", height: 577, sourceRank: 25 },
  { nameZh: "牛牯膊", height: 574, sourceRank: null },
  { nameZh: "雞公嶺", height: 572, sourceRank: null },
  { nameZh: "大刀屻", height: 566, sourceRank: 26 },
  { nameZh: "鱷魚朝天", height: 559, sourceRank: null },
  { nameZh: "扯旗山", height: 552, sourceRank: 27 },
  { nameZh: "犁壁山(八仙嶺)", height: 550, sourceRank: 28 },
  { nameZh: "觀音山", height: 550, sourceRank: 29 },
  { nameZh: "龍潭山", height: 550, sourceRank: null },
  { nameZh: "東山", height: 544, sourceRank: 30 },
  { nameZh: "果老峰", height: 543, sourceRank: 31 },
  { nameZh: "石芽山", height: 540, sourceRank: 32 },
  { nameZh: "狗牙嶺", height: 539, sourceRank: 33 },
  { nameZh: "大金鐘", height: 536, sourceRank: 34 },
  { nameZh: "東洋山", height: 533, sourceRank: 35 },
  { nameZh: "針山", height: 532, sourceRank: 36 },
  { nameZh: "柏架山", height: 532, sourceRank: 37 },
  { nameZh: "薄刀屻", height: 529, sourceRank: 38 },
  { nameZh: "鍾離峰", height: 529, sourceRank: 39 },
  { nameZh: "屏風山", height: 529, sourceRank: null },
  { nameZh: "拐李峰", height: 522, sourceRank: 40 },
  { nameZh: "芙蓉別", height: 514, sourceRank: 41 },
  { nameZh: "湘子峰", height: 513, sourceRank: 42 },
  { nameZh: "仙姑峰", height: 511, sourceRank: 43 },
  { nameZh: "曹舅峰", height: 508, sourceRank: 44 },
  { nameZh: "花山頭", height: 508, sourceRank: null },
  { nameZh: "九逕山", height: 507, sourceRank: 45 },
  { nameZh: "大嶺峒(元朗)", height: 503, sourceRank: 46 },
  { nameZh: "奇力山", height: 501, sourceRank: 47 },
  { nameZh: "獅子山", height: 495, sourceRank: 48 },
  { nameZh: "西高山", height: 494, sourceRank: 49 },
  { nameZh: "獅子頭山", height: 493, sourceRank: 50 },
  { nameZh: "紅花嶺", height: 492, sourceRank: 51 },
  { nameZh: "靈會山", height: 490, sourceRank: 52 },
  { nameZh: "紅花寨", height: 489, sourceRank: 53 },
  { nameZh: "采和峰", height: 489, sourceRank: 54 },
  { nameZh: "慈雲山", height: 488, sourceRank: 55 },
  { nameZh: "龜頭嶺", height: 486, sourceRank: 56 },
  { nameZh: "大石頂", height: 485, sourceRank: null },
  { nameZh: "婆髻山", height: 482, sourceRank: 57 },
  { nameZh: "石屋山", height: 481, sourceRank: 58 },
  { nameZh: "北大刀屻", height: 480, sourceRank: 59 },
  { nameZh: "木魚山", height: 479, sourceRank: 60 },
  { nameZh: "歌賦山", height: 479, sourceRank: 61 },
  { nameZh: "石龍拱", height: 474, sourceRank: 62 },
  { nameZh: "南山(八仙嶺)", height: 472, sourceRank: null },
  { nameZh: "蚺蛇尖", height: 468, sourceRank: 63 },
  { nameZh: "大磡森", height: 466, sourceRank: 64 },
  { nameZh: "老虎頭", height: 465, sourceRank: 65 },
  { nameZh: "和尚峒", height: 465, sourceRank: null },
  { nameZh: "田夫仔山", height: 461, sourceRank: 66 },
  { nameZh: "羗山", height: 459, sourceRank: 67 },
  { nameZh: "筆架山", height: 457, sourceRank: 68 },
  { nameZh: "岩頭山", height: 452, sourceRank: 69 },
  { nameZh: "象山(大嶼山)", height: 449, sourceRank: 70 },
  { nameZh: "長屻山", height: 443, sourceRank: 71 },
  { nameZh: "九龍坑山", height: 440, sourceRank: 72 },
  { nameZh: "二峒", height: 439, sourceRank: null },
  { nameZh: "雞胸山", height: 437, sourceRank: 73 },
  { nameZh: "畢拿山", height: 436, sourceRank: 74 },
  { nameZh: "三峒", height: 436, sourceRank: null },
  { nameZh: "觀音山", height: 434, sourceRank: 75 },
  { nameZh: "紫羅蘭山", height: 433, sourceRank: 76 },
  { nameZh: "渣甸山", height: 433, sourceRank: 77 },
  { nameZh: "鷓鴣山", height: 432, sourceRank: 78 },
  { nameZh: "望后石頂", height: 432, sourceRank: null },
  { nameZh: "聶高信山", height: 430, sourceRank: 79 },
  { nameZh: "深坑瀝", height: 430, sourceRank: 80 },
  { nameZh: "中狗牙嶺", height: 428, sourceRank: 81 },
  { nameZh: "小馬山", height: 424, sourceRank: 82 },
  { nameZh: "牛耳石山", height: 422, sourceRank: 83 },
  { nameZh: "竹篙屻嶺", height: 422, sourceRank: null },
  { nameZh: "大上托", height: 419, sourceRank: 84 },
  { nameZh: "吊燈籠", height: 416, sourceRank: 85 },
  { nameZh: "鹿巢山", height: 414, sourceRank: null },
  { nameZh: "饅頭墩", height: 413, sourceRank: null },
  { nameZh: "枕田山", height: 411, sourceRank: 86 },
  { nameZh: "金馬倫山", height: 410, sourceRank: 87 },
  { nameZh: "牌額山", height: 409, sourceRank: 88 },
  { nameZh: "大枕蓋", height: 408, sourceRank: 89 },
  { nameZh: "鹿山", height: 407, sourceRank: 90 },
  { nameZh: "北峰嶂", height: 400, sourceRank: null },
  { nameZh: "女婆山", height: 399, sourceRank: 91 },
  { nameZh: "九肚山", height: 399, sourceRank: 92 },
  { nameZh: "雞公山(西貢)", height: 399, sourceRank: 93 },
  { nameZh: "乾山", height: 394, sourceRank: 94 },
  { nameZh: "亞公頂", height: 394, sourceRank: null },
  { nameZh: "畫眉山", height: 391, sourceRank: 95 },
  { nameZh: "獅子頭", height: 390, sourceRank: null },
  { nameZh: "孖崗山南", height: 386, sourceRank: 96 },
  { nameZh: "尖尾峰", height: 385, sourceRank: 97 },
  { nameZh: "雷打石", height: 379, sourceRank: 98 },
  { nameZh: "榴花峒", height: 378, sourceRank: 99 },
  { nameZh: "圓頭山", height: 375, sourceRank: 100 },
  { nameZh: "雞公山(元朗)", height: 374, sourceRank: 101 },
  { nameZh: "牙鷹山", height: 373, sourceRank: 102 },
  { nameZh: "水泉澳", height: 373, sourceRank: null },
  { nameZh: "大蚊山", height: 370, sourceRank: 103 },
  { nameZh: "小指峰", height: 370, sourceRank: null },
  { nameZh: "牛坳山", height: 370, sourceRank: null },
  { nameZh: "金山", height: 369, sourceRank: 104 },
  { nameZh: "芬箕托", height: 369, sourceRank: 105 },
  { nameZh: "田尾山", height: 366, sourceRank: 106 },
  { nameZh: "孖崗山北", height: 363, sourceRank: 107 },
  { nameZh: "米粉頂", height: 363, sourceRank: null },
  { nameZh: "擔柴山", height: 361, sourceRank: 108 },
  { nameZh: "龍山", height: 360, sourceRank: 109 },
  { nameZh: "山地塘", height: 353, sourceRank: 110 },
  { nameZh: "歌連臣山", height: 348, sourceRank: 111 },
  { nameZh: "尖風山", height: 346, sourceRank: 112 },
  { nameZh: "釣魚翁", height: 344, sourceRank: 113 },
  { nameZh: "長連山", height: 344, sourceRank: 114 },
  { nameZh: "桃坑峒", height: 344, sourceRank: 115 },
  { nameZh: "尖峰山", height: 339, sourceRank: 116 },
  { nameZh: "石獅山", height: 338, sourceRank: 117 },
  { nameZh: "孖指徑", height: 337, sourceRank: 118 },
  { nameZh: "牛潭山", height: 337, sourceRank: 119 },
  { nameZh: "麻雀塘山", height: 336, sourceRank: null },
  { nameZh: "三支香", height: 334, sourceRank: 120 },
  { nameZh: "廟仔墩", height: 330, sourceRank: 121 },
  { nameZh: "鶴咀山", height: 325, sourceRank: 122 },
  { nameZh: "禾寮墩", height: 324, sourceRank: 123 },
  { nameZh: "獅山", height: 322, sourceRank: 124 },
  { nameZh: "寶雲山", height: 320, sourceRank: 125 },
  { nameZh: "太墩", height: 317, sourceRank: 126 },
  { nameZh: "下花山", height: 315, sourceRank: null },
  { nameZh: "西灣山(西貢)", height: 314, sourceRank: 127 },
  { nameZh: "芙蓉山", height: 314, sourceRank: null },
  { nameZh: "砵甸乍山", height: 312, sourceRank: 128 },
  { nameZh: "葵坳山", height: 312, sourceRank: 129 },
  { nameZh: "橫嶺", height: 311, sourceRank: 130 },
  { nameZh: "花香爐頂", height: 310, sourceRank: null },
  { nameZh: "尖山", height: 305, sourceRank: 131 },
  { nameZh: "五桂山", height: 304, sourceRank: 132 },
  { nameZh: "觀音峒", height: 304, sourceRank: 133 },
  { nameZh: "老人山", height: 303, sourceRank: 134 },
  { nameZh: "大輋峒", height: 302, sourceRank: 135 },
  { nameZh: "廟仔墩", height: 301, sourceRank: null },
  { nameZh: "桅尾嶺", height: 301, sourceRank: null },
  { nameZh: "東灣山", height: 298, sourceRank: 136 },
  { nameZh: "公庵山", height: 297, sourceRank: 137 },
  { nameZh: "禾徑山", height: 297, sourceRank: null },
  { nameZh: "馬頭峰", height: 295, sourceRank: 138 },
  { nameZh: "跌死狗", height: 295, sourceRank: 139 },
  { nameZh: "水婆婆山", height: 295, sourceRank: null },
  { nameZh: "老虎山", height: 293, sourceRank: null },
  { nameZh: "大嶺峒(西貢)", height: 291, sourceRank: 140 },
  { nameZh: "大山", height: 291, sourceRank: null },
  { nameZh: "石坳山", height: 291, sourceRank: null },
  { nameZh: "赤馬頭", height: 290, sourceRank: null },
  { nameZh: "四排石山", height: 290, sourceRank: null },
  { nameZh: "崗背頂", height: 290, sourceRank: null },
  { nameZh: "白水嶺", height: 290, sourceRank: null },
  { nameZh: "玉秀峰", height: 288, sourceRank: null },
  { nameZh: "鹿湖峒", height: 286, sourceRank: null },
  { nameZh: "南朗山", height: 284, sourceRank: 141 },
  { nameZh: "打爛埕頂山", height: 284, sourceRank: 142 },
  { nameZh: "五桂山南", height: 282, sourceRank: 143 },
  { nameZh: "尖指山", height: 282, sourceRank: null },
  { nameZh: "荔枝山", height: 282, sourceRank: null },
  { nameZh: "大蛇頂", height: 278, sourceRank: 144 },
  { nameZh: "大牛湖頂", height: 275, sourceRank: 145 },
  { nameZh: "茅園山", height: 275, sourceRank: null },
  { nameZh: "田下山", height: 273, sourceRank: 146 },
  { nameZh: "花瓶頂", height: 273, sourceRank: null },
  { nameZh: "南山(鑽石山)", height: 271, sourceRank: 147 },
  { nameZh: "馬夾崙", height: 271, sourceRank: null },
  { nameZh: "摩星嶺", height: 269, sourceRank: 148 },
  { nameZh: "馬坑山", height: 268, sourceRank: null },
  { nameZh: "疊石頂", height: 268, sourceRank: null },
  { nameZh: "黃茅嶺", height: 267, sourceRank: null },
  { nameZh: "雲枕山", height: 266, sourceRank: 149 },
  { nameZh: "龍虎山", height: 266, sourceRank: null },
  { nameZh: "餓死雞", height: 265, sourceRank: null },
  { nameZh: "牛湖墩", height: 263, sourceRank: 150 },
  { nameZh: "犁壁山(大嶼山)", height: 263, sourceRank: null },
  { nameZh: "下洋山", height: 263, sourceRank: null },
  { nameZh: "減龍嶺", height: 262, sourceRank: null },
  { nameZh: "野豬徑", height: 260, sourceRank: null },
  { nameZh: "上洋山", height: 260, sourceRank: null },
  { nameZh: "貓仔山", height: 258, sourceRank: null },
  { nameZh: "蓮花井山", height: 256, sourceRank: null },
  { nameZh: "箕勒仔", height: 256, sourceRank: null },
  { nameZh: "螺地墩", height: 255, sourceRank: null },
  { nameZh: "老虎騎石", height: 255, sourceRank: null },
  { nameZh: "圓墩山", height: 255, sourceRank: null },
  { nameZh: "田灣山", height: 252, sourceRank: null },
  { nameZh: "菱角山", height: 250, sourceRank: null },
  { nameZh: "多石頂", height: 250, sourceRank: null },
  { nameZh: "分流頂", height: 248, sourceRank: null },
  { nameZh: "照鏡環山", height: 247, sourceRank: null },
  { nameZh: "鐵矢山", height: 240, sourceRank: null },
  { nameZh: "金山尾", height: 238, sourceRank: null },
  { nameZh: "井坑山", height: 235, sourceRank: null },
  { nameZh: "大輋嶺墩", height: 235, sourceRank: null },
  { nameZh: "睇魚岩頂", height: 233, sourceRank: null },
  { nameZh: "橫頭墩", height: 232, sourceRank: null },
  { nameZh: "南堂頂", height: 232, sourceRank: null },
  { nameZh: "紅香爐峰", height: 230, sourceRank: null },
  { nameZh: "開丫峒", height: 228, sourceRank: null },
  { nameZh: "風門山", height: 226, sourceRank: null },
  { nameZh: "五肚嶺", height: 225, sourceRank: null },
  { nameZh: "琵琶山", height: 223, sourceRank: null },
  { nameZh: "東龍頭輋", height: 222, sourceRank: null },
  { nameZh: "魔鬼山", height: 222, sourceRank: null },
  { nameZh: "麒麟山", height: 222, sourceRank: null },
  { nameZh: "掌牛山", height: 220, sourceRank: null },
  { nameZh: "寮肚山", height: 219, sourceRank: null },
  { nameZh: "鵝髻頂", height: 219, sourceRank: null },
  { nameZh: "平托坑山", height: 216, sourceRank: null },
  { nameZh: "龜山(大潭)", height: 216, sourceRank: null },
  { nameZh: "茅湖山", height: 215, sourceRank: null },
  { nameZh: "班納山", height: 214, sourceRank: null },
  { nameZh: "獨孤山", height: 212, sourceRank: null },
  { nameZh: "大排塘頂", height: 212, sourceRank: null },
  { nameZh: "花山", height: 210, sourceRank: null },
  { nameZh: "鳳凰笏頂", height: 209, sourceRank: null },
  { nameZh: "雞麻峒", height: 207, sourceRank: null },
  { nameZh: "東龍尾輋", height: 206, sourceRank: null },
  { nameZh: "白角山", height: 205, sourceRank: null },
  { nameZh: "擺頭墩", height: 204, sourceRank: null },
  { nameZh: "寶馬山", height: 200, sourceRank: null },
  { nameZh: "玉桂山", height: 196, sourceRank: null },
  { nameZh: "社山", height: 196, sourceRank: null },
  { nameZh: "西灣山(柴灣)", height: 194, sourceRank: null },
  { nameZh: "雞公山(二澳)", height: 194, sourceRank: null },
  { nameZh: "牛湖頂", height: 188, sourceRank: null },
  { nameZh: "平山", height: 188, sourceRank: null },
  { nameZh: "大陰頂", height: 186, sourceRank: null },
  { nameZh: "鴉巢山", height: 184, sourceRank: null },
  { nameZh: "大石磨", height: 183, sourceRank: null },
  { nameZh: "北丫頂", height: 179, sourceRank: null },
  { nameZh: "蠄蟝石頂", height: 178, sourceRank: null },
  { nameZh: "沈雲山", height: 177, sourceRank: null },
  { nameZh: "涌沙頂", height: 175, sourceRank: null },
  { nameZh: "大嶺皮", height: 170, sourceRank: null },
  { nameZh: "少女峰", height: 167, sourceRank: null },
  { nameZh: "東心淇山", height: 165, sourceRank: null },
  { nameZh: "長山", height: 165, sourceRank: null },
  { nameZh: "觀音頂", height: 165, sourceRank: null },
  { nameZh: "犀牛望月", height: 164, sourceRank: null },
  { nameZh: "石碑山", height: 164, sourceRank: null },
  { nameZh: "爐仔石", height: 161, sourceRank: null },
  { nameZh: "牛皮沙頂", height: 160, sourceRank: null },
  { nameZh: "白虎山(西貢)", height: 156, sourceRank: null },
  { nameZh: "黃地峒", height: 154, sourceRank: null },
  { nameZh: "大嶺", height: 152, sourceRank: null },
  { nameZh: "鴨仔山", height: 152, sourceRank: null },
  { nameZh: "蠔殼山", height: 149, sourceRank: null },
  { nameZh: "壽臣山", height: 148, sourceRank: null },
  { nameZh: "蛇嶺", height: 143, sourceRank: null },
  { nameZh: "小陰頂", height: 143, sourceRank: null },
  { nameZh: "罾棚角頂", height: 141, sourceRank: null },
  { nameZh: "斧山", height: 140, sourceRank: null },
  { nameZh: "華山", height: 139, sourceRank: null },
  { nameZh: "錦山", height: 139, sourceRank: null },
  { nameZh: "馬頭嶺", height: 135, sourceRank: null },
  { nameZh: "鐵坑山", height: 134, sourceRank: null },
  { nameZh: "舂坎山", height: 133, sourceRank: null },
  { nameZh: "斜炮頂", height: 133, sourceRank: null },
  { nameZh: "昂莊山", height: 132, sourceRank: null },
  { nameZh: "獅地", height: 132, sourceRank: null },
  { nameZh: "道風山", height: 130, sourceRank: null },
  { nameZh: "大潭崗", height: 129, sourceRank: null },
  { nameZh: "長牌墩", height: 125, sourceRank: null },
  { nameZh: "茅平山", height: 125, sourceRank: null },
  { nameZh: "尖風山嘴", height: 122, sourceRank: null },
  { nameZh: "髻山", height: 121, sourceRank: null },
  { nameZh: "公主山", height: 118, sourceRank: null },
  { nameZh: "杉山", height: 115, sourceRank: null },
  { nameZh: "大浪頭", height: 110, sourceRank: null },
  { nameZh: "雞公崗", height: 108, sourceRank: null },
  { nameZh: "紅燈山", height: 107, sourceRank: null },
  { nameZh: "牛牯嶺", height: 106, sourceRank: null },
  { nameZh: "松山", height: 105, sourceRank: null },
  { nameZh: "三門墩", height: 104, sourceRank: null },
  { nameZh: "虎頭沙", height: 100, sourceRank: null },
  { nameZh: "白虎山(打鼓嶺)", height: 98, sourceRank: null },
  { nameZh: "手指山", height: 98, sourceRank: null },
  { nameZh: "格仔山", height: 98, sourceRank: null },
  { nameZh: "黑山頂", height: 95, sourceRank: null },
  { nameZh: "三門山", height: 95, sourceRank: null },
  { nameZh: "黃麻地", height: 93, sourceRank: null },
  { nameZh: "嘉頓山", height: 90, sourceRank: null },
  { nameZh: "望樓仔", height: 88, sourceRank: null },
  { nameZh: "蝴蝶山", height: 88, sourceRank: null },
  { nameZh: "採石山", height: 88, sourceRank: null },
  { nameZh: "窩仔山", height: 86, sourceRank: null },
  { nameZh: "上角頂", height: 85, sourceRank: null },
  { nameZh: "皇后山", height: 85, sourceRank: null },
  { nameZh: "十二號山", height: 84, sourceRank: null },
  { nameZh: "淋坑山", height: 81, sourceRank: null },
  { nameZh: "觀景山", height: 77, sourceRank: null },
  { nameZh: "老鼠嶺", height: 75, sourceRank: null },
  { nameZh: "虎山", height: 75, sourceRank: null },
  { nameZh: "企頭角頂", height: 74, sourceRank: null },
  { nameZh: "龜山(尖鼻咀)", height: 70, sourceRank: null },
  { nameZh: "大嶺頭", height: 69, sourceRank: null },
  { nameZh: "大浪咀", height: 50, sourceRank: null },
];

const featuredMountainNames = new Set(featuredMountains.map((mountain) => mountain.nameZh));
const importedMountains = timHikingPeaks
  .filter((peak) => !featuredMountainNames.has(peak.nameZh))
  .map((peak, index) => ({
    id: `timhiking-${String(index + 1).padStart(3, "0")}`,
    nameZh: peak.nameZh,
    nameEn: "",
    region: "Hong Kong",
    regionZh: "香港",
    height: peak.height,
    image: importedMountainImages[index % importedMountainImages.length],
    myCheckins: 0,
    rank: null,
    nextRankDistance: 1,
    totalCheckins: 0,
    sourceRank: peak.sourceRank,
    sourceUrl: timHikingSource.url,
    lastZh: "未打卡",
    lastEn: "Not checked in",
    coordinates: "N/A",
  }));

const mountains = [...featuredMountains, ...importedMountains];

const leaders = [
  { rank: 1, name: "山系行者", count: 68, subZh: "最後打卡：今日", subEn: "Last check-in: today" },
  { rank: 2, name: "Trail_HK", count: 43, subZh: "最後打卡：昨日", subEn: "Last check-in: yesterday" },
  { rank: 3, name: "自然探索者", count: 39, subZh: "最後打卡：本週", subEn: "Last check-in: this week" },
  { rank: 18, name: "You", count: 12, subZh: "即使不在前 10 名，也會顯示你的排名", subEn: "Always shown outside top 10", isUser: true },
];

const history = [
  { mountainId: "tai-mo-shan", dateZh: "今日", dateEn: "Today", time: "07:45", statusZh: "有效", statusEn: "Valid" },
  { mountainId: "lion-rock", dateZh: "6 月 4 日", dateEn: "4 Jun", time: "06:18", statusZh: "有效", statusEn: "Valid" },
  { mountainId: "lantau-peak", dateZh: "6 月 2 日", dateEn: "2 Jun", time: "05:52", statusZh: "有效", statusEn: "Valid" },
  { mountainId: "tai-mo-shan", dateZh: "5 月 29 日", dateEn: "29 May", time: "08:04", statusZh: "有效", statusEn: "Valid" },
];

const calendarSeed = [
  {
    mountainId: "tai-mo-shan",
    titleZh: "雲霧大帽山",
    titleEn: "Misty Tai Mo Shan",
    noteZh: "霧散之前完成山頂打卡，落山時剛好見到陽光。",
    noteEn: "Checked in before the mist cleared, then caught sunlight on the way down.",
    time: "07:42",
    tone: "mist",
  },
  {
    mountainId: "lion-rock",
    titleZh: "獅子山晨線",
    titleEn: "Lion Rock Morning Line",
    noteZh: "清晨路面乾爽，GPS 進入有效範圍後即場拍照。",
    noteEn: "Dry morning trail, live photo saved after GPS entered the valid area.",
    time: "06:18",
    tone: "rock",
  },
  {
    mountainId: "lantau-peak",
    titleZh: "鳳凰山日出",
    titleEn: "Lantau Peak Sunrise",
    noteZh: "日出前到頂，風大但能見度好。",
    noteEn: "Reached the summit before sunrise with strong wind and clear visibility.",
    time: "05:52",
    tone: "sun",
  },
  {
    mountainId: "sunset-peak",
    titleZh: "大東山草坡",
    titleEn: "Sunset Peak Grassland",
    noteZh: "沿草坡慢慢推進，完成今日連續打卡。",
    noteEn: "Moved steadily across the grassland and kept the streak alive.",
    time: "08:27",
    tone: "grass",
  },
  {
    mountainId: "tai-mo-shan",
    titleZh: "橙線補給站",
    titleEn: "Orange Line Refuel",
    noteZh: "補水後再上坡，今次用相片格保存路線記憶。",
    noteEn: "Refuelled before the climb and saved the route memory as a photo tile.",
    time: "17:36",
    tone: "orange",
  },
];

const calendarMonths = [
  {
    key: "2026-06",
    labelZh: "2026年6月",
    labelEn: "June 2026",
    startOffset: 0,
    days: 30,
    summaryZh: "本月 5 次有效打卡",
    summaryEn: "5 valid check-ins this month",
    entries: Array.from({ length: 5 }, (_, index) => createCalendarEntry("2026-06", index + 1, index)),
  },
  {
    key: "2026-05",
    labelZh: "2026年5月",
    labelEn: "May 2026",
    startOffset: 4,
    days: 31,
    summaryZh: "完成 31 日相片月曆",
    summaryEn: "31-day photo calendar completed",
    entries: Array.from({ length: 31 }, (_, index) => createCalendarEntry("2026-05", index + 1, index + 2)),
  },
  {
    key: "2026-04",
    labelZh: "2026年4月",
    labelEn: "April 2026",
    startOffset: 2,
    days: 30,
    summaryZh: "24 次山峰打卡",
    summaryEn: "24 mountain check-ins",
    entries: Array.from({ length: 24 }, (_, index) => createCalendarEntry("2026-04", index + 1, index + 4)),
  },
];

const regions = [
  { value: "All", zh: "全部", en: "All" },
  { value: "Hong Kong", zh: "香港", en: "Hong Kong" },
  { value: "New Territories", zh: "新界", en: "New Territories" },
  { value: "Kowloon", zh: "九龍", en: "Kowloon" },
  { value: "Lantau", zh: "大嶼山", en: "Lantau" },
];

const homeSortOptions = [
  { value: "rank", zh: "300峰", en: "Top 300" },
  { value: "height", zh: "高度", en: "Height" },
  { value: "checked", zh: "已打卡", en: "Checked" },
  { value: "open", zh: "未打卡", en: "Open" },
];

const homeListChunkSize = 40;
const mapHeightRange = { min: 176, max: 430, compact: 208, large: 360 };

const mapClusters = {
  nt: { xMin: 28, xMax: 88, yMin: 15, yMax: 54 },
  kowloon: { xMin: 58, xMax: 79, yMin: 53, yMax: 68 },
  lantau: { xMin: 10, xMax: 48, yMin: 58, yMax: 84 },
  island: { xMin: 57, xMax: 91, yMin: 70, yMax: 87 },
};

const state = {
  screen: "home",
  selectedMountainId: "tai-mo-shan",
  region: "All",
  query: "",
  homeSort: "rank",
  homeListLimit: homeListChunkSize,
  mapHeight: mapHeightRange.compact,
  didCheckIn: false,
  proofMode: "camera",
  lang: "zh",
  calendarRange: "month",
  calendarMonthKey: "2026-06",
  selectedCalendarEntryId: "2026-06-05",
};

const icons = {
  bell: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M10 21h4"/><path d="M18 8a6 6 0 0 0-12 0c0 7-3 8-3 8h18s-3-1-3-8"/></svg>',
  filter: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 5h18"/><path d="M7 12h10"/><path d="M10 19h4"/></svg>',
  search: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/></svg>',
  mountain: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m3 20 7-14 4 8 2-4 5 10Z"/><path d="m10 6 2 4"/></svg>',
  compass: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="m15.5 8.5-2.2 5.8-5.8 2.2 2.2-5.8Z"/></svg>',
  target: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="3"/><path d="M12 2v3"/><path d="M12 19v3"/><path d="M2 12h3"/><path d="M19 12h3"/></svg>',
  records: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 20V9"/><path d="M12 20V4"/><path d="M19 20v-7"/></svg>',
  calendar: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M8 2v4"/><path d="M16 2v4"/><rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18"/></svg>',
  user: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="8" r="4"/><path d="M4 21c1.5-4 5-6 8-6s6.5 2 8 6"/></svg>',
  pin: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 21s7-5.7 7-12a7 7 0 1 0-14 0c0 6.3 7 12 7 12Z"/><circle cx="12" cy="9" r="2.5"/></svg>',
  check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="m5 12 5 5L20 7"/></svg>',
  shield: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z"/><path d="m9 12 2 2 4-5"/></svg>',
  clock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>',
  camera: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14.5 4 16 7h3a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2h3l1.5-3Z"/><circle cx="12" cy="14" r="4"/></svg>',
  upload: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 16V4"/><path d="m7 9 5-5 5 5"/><path d="M4 20h16"/></svg>',
  lock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/></svg>',
  map: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m3 6 6-3 6 3 6-3v15l-6 3-6-3-6 3Z"/><path d="M9 3v15"/><path d="M15 6v15"/></svg>',
  chevron: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="m9 18 6-6-6-6"/></svg>',
  back: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="m15 18-6-6 6-6"/></svg>',
  accuracy: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="7"/><path d="M12 2v3"/><path d="M12 19v3"/><path d="M2 12h3"/><path d="M19 12h3"/></svg>',
  people: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.9"/><path d="M16 3.1a4 4 0 0 1 0 7.8"/></svg>',
  trophy: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M8 21h8"/><path d="M12 17v4"/><path d="M7 4h10v5a5 5 0 0 1-10 0Z"/><path d="M5 5H3v2a4 4 0 0 0 4 4"/><path d="M19 5h2v2a4 4 0 0 1-4 4"/></svg>',
  settings: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.2a1.7 1.7 0 0 0-1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.2a1.7 1.7 0 0 0 1.5-1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3 1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.2a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8 1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.2a1.7 1.7 0 0 0-1.4 1Z"/></svg>',
};

const copy = {
  zh: {
    appLabel: "WildFrog 手機 app 原型",
    title: "WildFrog 山野紀錄草稿",
    brandSub: "香港山峰紀錄",
    notifications: "通知",
    languageLabel: "切換至英文",
    languageText: "EN",
    searchPlaceholder: "搜尋山峰",
    filterMountains: "篩選山峰",
    regionFilter: "地區篩選",
    emptyMountains: "找不到符合的山峰",
    homeEyebrow: "P0 原型",
    homeHeadline: "每座山都有自己的打卡紀錄",
    homeIntro: "到達有效範圍後解鎖相片證明，再生成官方山峰印章。",
    mountainCount: "山峰",
    todayReady: "GPS 檢查就緒",
    myCheckins: "我的打卡",
    myRank: "我的排名",
    top300Rank: "300峰排名",
    source: "資料來源",
    unranked: "未排名",
    totalCheckins: "總打卡",
    backToList: "返回山峰列表",
    map: "地圖",
    mountainMap: "山峰地圖",
    mapOverview: "全港山峰概覽",
    mapCompact: "細",
    mapLarge: "大",
    resizeMap: "拉動調整地圖大小",
    featuredMountains: "精選山峰",
    allMountains: "山峰列表",
    showingMountains: "顯示山峰",
    loadMore: "載入更多",
    listedMountains: "列表山峰",
    checkedStatus: "打卡狀態",
    myRecord: "我的紀錄",
    validCheckins: "有效打卡",
    toNextRank: "距離下一名",
    checkIn: "打卡",
    leaderboard: "排行榜",
    total: "總榜",
    valid: "有效",
    you: "你",
    backToDetail: "返回山峰詳情",
    gpsCheckIn: "GPS 打卡",
    checkpointMap: "檢查點地圖",
    gpsStatus: "GPS 狀態",
    good: "良好",
    distanceToCheckpoint: "距離檢查點",
    validRadius: "有效半徑",
    gpsAccuracy: "GPS 精準度",
    photoProof: "相片證明",
    photoProofSub: "進入檢查點範圍後解鎖",
    validArea: "有效範圍",
    proofMethod: "相片證明方式",
    takePhoto: "即場拍照",
    uploadPhoto: "上載相片",
    validCheckIn: "有效打卡",
    cameraStamp: "即場相片印章",
    uploadStamp: "上載相片印章",
    cameraCaption: "在有效範圍內拍攝，系統會加上官方山峰印章。",
    uploadCaption: "上載相片只作證明，位置仍需保持有效才會蓋章。",
    checkInNow: "立即完成打卡",
    lockNote: "離開有效半徑時，此步驟會保持鎖定。",
    safetyCopy: "先確認天氣及路況，遵守封閉區域，危險地形上不要邊行邊用手機。",
    details: "詳情",
    successTitle: "打卡成功",
    successCopy: "此山峰的排行榜紀錄已更新。",
    rank: "排名",
    nextRank: "下一名",
    backToMountain: "返回山峰",
    explore: "探索",
    exploreSub: "地區與檢查點",
    mapFilters: "地圖篩選",
    nearbyRecords: "附近紀錄",
    records: "紀錄",
    recordsSub: "有效山峰歷史",
    calendarRecords: "日曆紀錄",
    calendarRecordsSub: "用相片格睇返每次有效打卡",
    today: "今日",
    thisMonth: "本月",
    thisYear: "今年",
    monthSummary: "月度摘要",
    previousMonth: "上一月",
    nextMonth: "下一月",
    selectedCheckin: "選中打卡",
    calendarEmpty: "未有打卡",
    photoCalendar: "相片月曆",
    monthCheckins: "月內打卡",
    streakDays: "連續日數",
    summitCertificate: "WildFrog 山峰紀錄",
    summitCertificateTitle: "登頂紀念證書",
    summitCount: "登頂次數",
    mountainElevation: "山峰海拔",
    summitDate: "登頂時間",
    officialRecord: "官方有效紀錄",
    activityMotto: "愛自然 / 愛運動 / 愛香港",
    verifyRecord: "驗證紀錄",
    viewMountain: "查看山峰",
    proofSaved: "證明已保存",
    yearOverview: "全年月曆",
    recentMonth: "最近月份",
    privacy: "私隱",
    totalValid: "有效打卡總數",
    mountainsVisited: "已到訪山峰",
    bestMountainCount: "最高山峰次數",
    checkinHistory: "打卡歷史",
    privateCoordinates: "精確座標不公開",
    settings: "設定",
    profileLocation: "香港 · 2022 起開始行山",
    mostVisited: "最多到訪",
    topMountainRecords: "最高山峰紀錄",
    privateProfile: "私人個人檔案",
    privateProfileCopy: "排行榜不會公開精確座標。",
    privateProfileEnabled: "私人個人檔案已啟用",
    checkins: "次打卡",
    navPrimary: "主要導覽",
    home: "首頁",
    profile: "個人",
  },
  en: {
    appLabel: "WildFrog mobile app prototype",
    title: "WildFrog App Draft",
    brandSub: "Mountain records",
    notifications: "Notifications",
    languageLabel: "Switch to Traditional Chinese",
    languageText: "中",
    searchPlaceholder: "Search mountains",
    filterMountains: "Filter mountains",
    regionFilter: "Region filter",
    emptyMountains: "No matching mountains",
    homeEyebrow: "P0 prototype",
    homeHeadline: "Every mountain keeps its own record",
    homeIntro: "Reach the valid area, unlock photo proof, then generate the official mountain stamp.",
    mountainCount: "mountains",
    todayReady: "GPS proof ready",
    myCheckins: "My check-ins",
    myRank: "My rank",
    top300Rank: "Top 300 rank",
    source: "Source",
    unranked: "Unranked",
    totalCheckins: "Total check-ins",
    backToList: "Back to mountain list",
    map: "Map",
    mountainMap: "Mountain map",
    mapOverview: "Hong Kong mountain overview",
    mapCompact: "Small",
    mapLarge: "Large",
    resizeMap: "Drag to resize map",
    featuredMountains: "Featured mountains",
    allMountains: "Mountain list",
    showingMountains: "Showing mountains",
    loadMore: "Load more",
    listedMountains: "Listed mountains",
    checkedStatus: "Check-in status",
    myRecord: "My Record",
    validCheckins: "Valid check-ins",
    toNextRank: "To next rank",
    checkIn: "Check In",
    leaderboard: "Leaderboard",
    total: "Total",
    valid: "valid",
    you: "You",
    backToDetail: "Back to mountain detail",
    gpsCheckIn: "GPS Check-in",
    checkpointMap: "Checkpoint map",
    gpsStatus: "GPS status",
    good: "Good",
    distanceToCheckpoint: "Distance to checkpoint",
    validRadius: "Valid radius",
    gpsAccuracy: "GPS accuracy",
    photoProof: "Photo proof",
    photoProofSub: "Unlocked inside checkpoint area",
    validArea: "Valid area",
    proofMethod: "Photo proof method",
    takePhoto: "Take photo",
    uploadPhoto: "Upload photo",
    validCheckIn: "Valid check-in",
    cameraStamp: "On-site photo stamp",
    uploadStamp: "Upload photo stamp",
    cameraCaption: "Capture in the valid area, then the app adds the official mountain stamp.",
    uploadCaption: "Uploaded photos get the same official stamp after location stays valid.",
    checkInNow: "Check In Now",
    lockNote: "Outside the valid radius, this step stays locked.",
    safetyCopy: "Check weather, respect restricted areas, and avoid using your phone while moving through unsafe terrain.",
    details: "details",
    successTitle: "check-in successful",
    successCopy: "Your leaderboard count was updated for this mountain.",
    rank: "Rank",
    nextRank: "Next rank",
    backToMountain: "Back to mountain",
    explore: "Explore",
    exploreSub: "Regions and checkpoints",
    mapFilters: "Map filters",
    nearbyRecords: "Nearby records",
    records: "Records",
    recordsSub: "Valid mountain history",
    calendarRecords: "Calendar records",
    calendarRecordsSub: "Review every valid check-in as photo tiles",
    today: "Today",
    thisMonth: "This month",
    thisYear: "This year",
    monthSummary: "Month summary",
    previousMonth: "Previous month",
    nextMonth: "Next month",
    selectedCheckin: "Selected check-in",
    calendarEmpty: "No check-in",
    photoCalendar: "Photo calendar",
    monthCheckins: "Month check-ins",
    streakDays: "Streak days",
    summitCertificate: "WildFrog Mountain Record",
    summitCertificateTitle: "Summit Certificate",
    summitCount: "Summit count",
    mountainElevation: "Elevation",
    summitDate: "Summit date",
    officialRecord: "Official valid record",
    activityMotto: "Love nature / Love motion / Love Hong Kong",
    verifyRecord: "Verify record",
    viewMountain: "View mountain",
    proofSaved: "Proof saved",
    yearOverview: "Year calendar",
    recentMonth: "Recent month",
    privacy: "Privacy",
    totalValid: "Total valid check-ins",
    mountainsVisited: "Mountains visited",
    bestMountainCount: "Best mountain count",
    checkinHistory: "Check-in history",
    privateCoordinates: "Private coordinates",
    settings: "Settings",
    profileLocation: "Hong Kong · Hiker since 2022",
    mostVisited: "Most visited",
    topMountainRecords: "Top mountain records",
    privateProfile: "Private profile",
    privateProfileCopy: "Exact coordinates stay hidden from public leaderboards.",
    privateProfileEnabled: "Private profile enabled",
    checkins: "check-ins",
    navPrimary: "Primary",
    home: "Home",
    profile: "Profile",
  },
};

function byId(id) {
  return document.getElementById(id);
}

function t(key) {
  return copy[state.lang][key];
}

function localized(valueZh, valueEn) {
  return state.lang === "zh" ? valueZh : valueEn;
}

function selectedMountain() {
  return mountains.find((mountain) => mountain.id === state.selectedMountainId) || mountains[0];
}

function formatNumber(value) {
  return new Intl.NumberFormat(state.lang === "zh" ? "zh-HK" : "en-US").format(value);
}

function regionLabel(region) {
  const match = regions.find((item) => item.value === region);
  if (!match) return region;
  return localized(match.zh, match.en);
}

function mountainTitle(mountain) {
  const nameEn = mountain.nameEn?.trim();
  if (!nameEn || nameEn === mountain.nameZh) return mountain.nameZh;
  return state.lang === "zh" ? `${mountain.nameZh} ${mountain.nameEn}` : `${mountain.nameEn} ${mountain.nameZh}`;
}

function sourceRankText(mountain) {
  return mountain.sourceRank ? `#${mountain.sourceRank}` : t("unranked");
}

function sourceSummary(mountain) {
  const sourceName = localized(timHikingSource.zh, timHikingSource.en);
  return `${sourceName} · ${sourceRankText(mountain)}`;
}

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function clampMapHeight(value) {
  return clamp(Math.round(value), mapHeightRange.min, mapHeightRange.max);
}

function homeFilteredMountains() {
  const query = state.query.trim().toLowerCase();
  return mountains.filter((mountain) => {
    const matchesRegion = state.region === "All" || mountain.region === state.region;
    const haystack = `${mountain.nameZh} ${mountain.nameEn} ${mountain.region} ${mountain.regionZh}`.toLowerCase();
    return matchesRegion && (!query || haystack.includes(query));
  });
}

function rankSortValue(mountain) {
  return mountain.sourceRank || 9999;
}

function homeSortedMountains(items) {
  let visible = [...items];

  if (state.homeSort === "checked") {
    visible = visible.filter((mountain) => mountain.myCheckins > 0);
    return visible.sort((a, b) => b.myCheckins - a.myCheckins || rankSortValue(a) - rankSortValue(b));
  }

  if (state.homeSort === "open") {
    visible = visible.filter((mountain) => mountain.myCheckins === 0);
    return visible.sort((a, b) => rankSortValue(a) - rankSortValue(b) || b.height - a.height);
  }

  if (state.homeSort === "height") {
    return visible.sort((a, b) => b.height - a.height || rankSortValue(a) - rankSortValue(b));
  }

  return visible.sort((a, b) => rankSortValue(a) - rankSortValue(b) || b.height - a.height);
}

function homeResultText(total, showing) {
  return state.lang === "zh" ? `顯示 ${showing} / ${total} 座` : `Showing ${showing} / ${total}`;
}

function listStatusText(mountain) {
  if (mountain.myCheckins > 0) {
    return state.lang === "zh" ? `${mountain.myCheckins} 次` : `${mountain.myCheckins}x`;
  }
  return state.lang === "zh" ? "未打卡" : "Open";
}

function compactRankText(mountain) {
  return mountain.sourceRank ? `#${mountain.sourceRank}` : state.lang === "zh" ? "未" : "—";
}

function parseCoordinates(coordinates) {
  const match = String(coordinates || "").match(/(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)/);
  if (!match) return null;
  return { lat: Number(match[1]), lng: Number(match[2]) };
}

function projectCoordinate({ lat, lng }) {
  const bounds = { latMin: 22.15, latMax: 22.57, lngMin: 113.82, lngMax: 114.43 };
  return {
    x: clamp(((lng - bounds.lngMin) / (bounds.lngMax - bounds.lngMin)) * 100, 5, 95),
    y: clamp(((bounds.latMax - lat) / (bounds.latMax - bounds.latMin)) * 100, 8, 92),
  };
}

function mountainHash(value) {
  return Array.from(value).reduce((hash, char) => (hash * 31 + char.charCodeAt(0)) % 1000003, 17);
}

function inferredMapCluster(mountain) {
  const name = mountain.nameZh;

  if (mountain.region === "Lantau" || /大嶼|鳳凰|大東|二東|彌勒|狗牙|昂坪|羌山|羗山|石壁|老虎頭|大澳|梅窩|芝麻灣/.test(name)) {
    return "lantau";
  }

  if (/扯旗|奇力|西高|柏架|畢拿|渣甸|聶高信|紫羅蘭|港島|太平山|龍脊|歌賦山/.test(name)) {
    return "island";
  }

  if (mountain.region === "Kowloon" || /獅子|飛鵝|大老山|慈雲|九龍|東山|東洋山|釣魚翁|清水灣|魔鬼|將軍澳/.test(name)) {
    return "kowloon";
  }

  if (mountain.region === "New Territories" || /大帽|馬鞍|草山|針山|八仙|黃嶺|水牛|黃牛|青山|大刀|禾秧|禾塘|吊手|牛押|雞公嶺|九逕|大欖|大埔|西貢|荃灣|屯門|沙田/.test(name)) {
    return "nt";
  }

  const bucket = mountainHash(`${name}-${mountain.height}`) % 10;
  if (bucket < 2) return "lantau";
  if (bucket < 4) return "island";
  if (bucket < 5) return "kowloon";
  return "nt";
}

function clusterPoint(mountain) {
  const cluster = mapClusters[inferredMapCluster(mountain)];
  const hash = mountainHash(`${mountain.nameZh}-${mountain.height}-${mountain.sourceRank || 0}`);
  const xRatio = (hash % 997) / 996;
  const yRatio = (Math.floor(hash / 997) % 997) / 996;
  return {
    x: cluster.xMin + (cluster.xMax - cluster.xMin) * xRatio,
    y: cluster.yMin + (cluster.yMax - cluster.yMin) * yRatio,
  };
}

function mapPointForMountain(mountain) {
  const coordinate = parseCoordinates(mountain.coordinates);
  return coordinate ? projectCoordinate(coordinate) : clusterPoint(mountain);
}

function mapPinSize(mountain) {
  if (mountain.myCheckins > 0) return 12;
  if (mountain.sourceRank && mountain.sourceRank <= 50) return 9;
  return 6;
}

function userRankText(mountain) {
  return mountain.rank ? `#${mountain.rank}` : "—";
}

function userRankAfterCheckInText(mountain) {
  if (!mountain.rank) return t("unranked");
  return `#${Math.max(1, mountain.rank - 1)}`;
}

function calendarDateParts(monthKey, day) {
  const [year, month] = monthKey.split("-").map(Number);
  const date = new Date(year, month - 1, day);
  const zhWeeks = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"];
  const enWeeks = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  const enMonth = new Intl.DateTimeFormat("en-US", { month: "short" }).format(date);

  return {
    dateISO: `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`,
    dateZh: `${month}月${day}日 / ${zhWeeks[date.getDay()]}`,
    dateEn: `${day} ${enMonth} / ${enWeeks[date.getDay()]}`,
  };
}

function createCalendarEntry(monthKey, day, seedIndex) {
  const seed = calendarSeed[seedIndex % calendarSeed.length];
  const mountain = mountains.find((candidate) => candidate.id === seed.mountainId) || mountains[0];
  const dateParts = calendarDateParts(monthKey, day);

  return {
    ...seed,
    ...dateParts,
    id: `${monthKey}-${String(day).padStart(2, "0")}`,
    day,
    image: mountain.image,
    count: 1 + ((day + seedIndex) % 3),
  };
}

function activeCalendarMonth() {
  return calendarMonths.find((month) => month.key === state.calendarMonthKey) || calendarMonths[0];
}

function calendarEntryById(id) {
  return calendarMonths.flatMap((month) => month.entries).find((entry) => entry.id === id) || calendarMonths[0].entries.at(-1);
}

function calendarEntriesByDay(month) {
  return new Map(month.entries.map((entry) => [entry.day, entry]));
}

function summitCountText(count) {
  return state.lang === "zh" ? `第 ${count} 次登頂` : `Summit #${count}`;
}

function renderLanguageToggle() {
  return `
    <button class="lang-toggle" data-action="toggle-language" aria-label="${t("languageLabel")}">
      ${t("languageText")}
    </button>
  `;
}

function render() {
  const app = byId("app");
  document.documentElement.lang = state.lang === "zh" ? "zh-Hant-HK" : "en";
  document.title = t("title");
  app.innerHTML = `
    <div class="app-shell">
      ${renderScreen()}
      ${renderNav()}
    </div>
  `;
  bindEvents();
}

function renderScreen() {
  if (state.screen === "home") return renderHome();
  if (state.screen === "explore") return renderExplore();
  if (state.screen === "detail") return renderDetail();
  if (state.screen === "checkin") return renderCheckIn();
  if (state.screen === "success") return renderSuccess();
  if (state.screen === "records") return renderRecords();
  if (state.screen === "profile") return renderProfile();
  return renderHome();
}

function renderHome() {
  const filtered = homeFilteredMountains();
  const sorted = homeSortedMountains(filtered);
  const visible = sorted.slice(0, state.homeListLimit);

  return `
    <section class="screen fade-in" data-screen="home">
      <header class="screen-header">
        <div class="brand">
          <div class="brand-mark">${icons.mountain}</div>
          <div>
            <h1>WildFrog</h1>
            <p>${t("brandSub")}</p>
          </div>
        </div>
        <div class="header-actions">
          ${renderLanguageToggle()}
          <button class="icon-button" aria-label="${t("notifications")}">${icons.bell}</button>
        </div>
      </header>

      <section class="home-summary" aria-label="${t("homeHeadline")}">
        <div>
          <span class="eyebrow">${t("homeEyebrow")}</span>
          <h2>${t("homeHeadline")}</h2>
          <p>${t("homeIntro")}</p>
        </div>
        <div class="summary-meter">
          <strong>${mountains.length}</strong>
          <span>${t("mountainCount")}</span>
        </div>
      </section>

      <section class="activity-strip" aria-label="${t("recordsSub")}">
        <div class="activity-stat">
          ${icons.records}
          <div><strong>86</strong><span>${t("totalValid")}</span></div>
        </div>
        <div class="activity-stat">
          ${icons.mountain}
          <div><strong>14</strong><span>${t("mountainsVisited")}</span></div>
        </div>
        <div class="activity-stat">
          ${icons.trophy}
          <div><strong>#18</strong><span>${t("myRank")}</span></div>
        </div>
      </section>

      <div class="search-row">
        <label class="search-field">
          ${icons.search}
          <input id="searchInput" type="search" value="${escapeHtml(state.query)}" placeholder="${t("searchPlaceholder")}" autocomplete="off" />
        </label>
        <button class="icon-button" aria-label="${t("filterMountains")}">${icons.filter}</button>
      </div>

      <div class="chip-row" role="tablist" aria-label="${t("regionFilter")}">
        ${regions
          .map(
            (region) => `
              <button class="chip ${state.region === region.value ? "is-active" : ""}" data-region="${region.value}" role="tab" aria-selected="${state.region === region.value}">
                ${localized(region.zh, region.en)}
              </button>
            `
          )
          .join("")}
      </div>

      ${renderHomeMap(sorted)}
      ${state.query.trim() ? "" : renderFeaturedRail()}
      ${renderDirectoryPanel(sorted, visible)}
    </section>
  `;
}

function renderFeaturedRail() {
  return `
    <section class="featured-section" aria-label="${t("featuredMountains")}">
      <div class="section-title">
        <span>${t("featuredMountains")}</span>
        <strong>${featuredMountains.length}</strong>
      </div>
      <div class="featured-rail">
        ${featuredMountains
          .map(
            (mountain) => `
              <button class="featured-mountain" data-open-detail="${mountain.id}" style="--image: url('${mountain.image}')" aria-label="${mountainTitle(mountain)}">
                <span>${sourceRankText(mountain)}</span>
                <strong>${mountainTitle(mountain)}</strong>
                <small>${mountain.height}m · ${listStatusText(mountain)}</small>
              </button>
            `
          )
          .join("")}
      </div>
    </section>
  `;
}

function renderHomeMap(mountainList) {
  const checkedCount = mountainList.filter((mountain) => mountain.myCheckins > 0).length;
  return `
    <section class="map-overview" style="--map-height: ${state.mapHeight}px" aria-label="${t("mountainMap")}">
      <div class="map-toolbar">
        <div>
          <span class="eyebrow">${t("mountainMap")}</span>
          <strong>${t("mapOverview")}</strong>
        </div>
        <div class="map-size-controls" aria-label="${t("resizeMap")}">
          <button class="map-size-button ${state.mapHeight <= mapHeightRange.compact ? "is-active" : ""}" data-map-size="compact">${t("mapCompact")}</button>
          <button class="map-size-button ${state.mapHeight >= mapHeightRange.large ? "is-active" : ""}" data-map-size="large">${t("mapLarge")}</button>
        </div>
      </div>
      <button class="map-resize-handle" data-map-resize-handle type="button" aria-label="${t("resizeMap")}" aria-valuemin="${mapHeightRange.min}" aria-valuemax="${mapHeightRange.max}" aria-valuenow="${state.mapHeight}">
        <span></span>
      </button>
      <div class="map-canvas">
        <span class="map-grid-line map-grid-line-a" aria-hidden="true"></span>
        <span class="map-grid-line map-grid-line-b" aria-hidden="true"></span>
        <span class="map-landmass map-nt" aria-hidden="true"></span>
        <span class="map-landmass map-lantau" aria-hidden="true"></span>
        <span class="map-landmass map-kowloon" aria-hidden="true"></span>
        <span class="map-landmass map-island" aria-hidden="true"></span>
        <span class="map-label map-label-nt">${localized("新界", "NT")}</span>
        <span class="map-label map-label-lantau">${localized("大嶼", "Lantau")}</span>
        <span class="map-label map-label-kowloon">${localized("九龍", "Kowloon")}</span>
        <span class="map-label map-label-island">${localized("港島", "HK Island")}</span>
        <div class="map-pins">
          ${mountainList.length ? mountainList.map(renderMapPin).join("") : ""}
        </div>
        <div class="map-stat-chip">
          <strong>${formatNumber(mountainList.length)}</strong>
          <span>${t("listedMountains")}</span>
        </div>
        <div class="map-stat-chip is-secondary">
          <strong>${formatNumber(checkedCount)}</strong>
          <span>${t("checkedStatus")}</span>
        </div>
      </div>
    </section>
  `;
}

function renderMapPin(mountain) {
  const point = mapPointForMountain(mountain);
  const classes = [
    "map-pin",
    mountain.myCheckins > 0 ? "is-checked" : "",
    mountain.sourceRank ? "is-ranked" : "",
    featuredMountainNames.has(mountain.nameZh) ? "is-featured" : "",
  ]
    .filter(Boolean)
    .join(" ");

  return `
    <button
      class="${classes}"
      data-open-detail="${mountain.id}"
      style="--x: ${point.x.toFixed(1)}%; --y: ${point.y.toFixed(1)}%; --pin-size: ${mapPinSize(mountain)}px"
      aria-label="${mountainTitle(mountain)} ${mountain.height}m ${sourceRankText(mountain)}"
    >
      <span></span>
    </button>
  `;
}

function renderDirectoryPanel(mountainList, visibleMountains) {
  const canLoadMore = visibleMountains.length < mountainList.length;
  return `
    <section class="directory-panel" aria-label="${t("allMountains")}">
      <div class="directory-toolbar">
        <div>
          <span class="eyebrow">${t("allMountains")}</span>
          <strong>${homeResultText(mountainList.length, visibleMountains.length)}</strong>
        </div>
        <div class="sort-tabs" role="tablist" aria-label="${t("showingMountains")}">
          ${homeSortOptions
            .map(
              (option) => `
                <button class="sort-tab ${state.homeSort === option.value ? "is-active" : ""}" data-home-sort="${option.value}" role="tab" aria-selected="${state.homeSort === option.value}">
                  ${localized(option.zh, option.en)}
                </button>
              `
            )
            .join("")}
        </div>
      </div>
      <div class="mountain-directory-list">
        ${visibleMountains.length ? visibleMountains.map(renderMountainRow).join("") : `<div class="empty-state">${t("emptyMountains")}</div>`}
      </div>
      ${
        canLoadMore
          ? `<button class="load-more-button" data-load-more type="button">${t("loadMore")} · ${homeResultText(mountainList.length, visibleMountains.length)}</button>`
          : ""
      }
    </section>
  `;
}

function renderMountainRow(mountain) {
  return `
    <button class="mountain-row" data-open-detail="${mountain.id}" aria-label="${mountainTitle(mountain)} ${mountain.height}m">
      <span class="rank-pill">${compactRankText(mountain)}</span>
      <span class="row-main">
        <strong>${mountainTitle(mountain)}</strong>
        <small>${regionLabel(mountain.region)} · ${mountain.height}m · ${sourceSummary(mountain)}</small>
      </span>
      <span class="row-status ${mountain.myCheckins > 0 ? "is-checked" : ""}">${listStatusText(mountain)}</span>
      <span class="row-chevron" aria-hidden="true">${icons.chevron}</span>
    </button>
  `;
}

function renderMountainCard(mountain) {
  return `
    <button class="mountain-card" data-open-detail="${mountain.id}" style="--image: url('${mountain.image}')">
      <div class="card-head">
        <div class="card-title">
          <h2>${mountainTitle(mountain)}</h2>
          <p>${regionLabel(mountain.region)} · ${sourceRankText(mountain)} · ${t("todayReady")}</p>
        </div>
        <span class="height-badge">${mountain.height}m</span>
      </div>
      <div class="card-metrics">
        <div class="metric">
          ${icons.mountain}
          <div><small>${t("myCheckins")}</small><strong>${mountain.myCheckins}</strong></div>
        </div>
        <div class="metric">
          ${icons.trophy}
          <div><small>${t("top300Rank")}</small><strong class="rank">${sourceRankText(mountain)}</strong></div>
        </div>
        <div class="metric">
          ${icons.people}
          <div><small>${t("totalCheckins")}</small><strong>${formatNumber(mountain.totalCheckins)}</strong></div>
        </div>
      </div>
    </button>
  `;
}

function renderDetail() {
  const mountain = selectedMountain();
  return `
    <section class="screen fade-in" data-screen="detail">
      <div class="detail-hero" style="--image: url('${mountain.image}')">
        <header class="screen-header">
          <button class="icon-button" data-screen-target="home" aria-label="${t("backToList")}">${icons.back}</button>
          <div class="hero-actions">
            <button class="icon-button" aria-label="${t("map")}">${icons.map}</button>
          </div>
        </header>
        <div class="detail-title">
          <h1>${mountainTitle(mountain)}</h1>
          <p>${icons.pin} ${regionLabel(mountain.region)} · ${mountain.height}m · ${sourceSummary(mountain)}</p>
        </div>
      </div>

      <section class="section">
        <div class="section-title">
          <h2>${t("myRecord")}</h2>
          <span>${localized(mountain.lastZh, mountain.lastEn)}</span>
        </div>
        <div class="record-panel">
          <div class="record-grid">
            <div class="record-cell"><span>${t("validCheckins")}</span><strong>${mountain.myCheckins}</strong></div>
            <div class="record-cell"><span>${t("top300Rank")}</span><strong class="accent">${sourceRankText(mountain)}</strong></div>
            <div class="record-cell"><span>${t("source")}</span><strong>TimHiking</strong></div>
          </div>
        </div>
        <button class="primary-action" data-screen-target="checkin">${icons.target} ${t("checkIn")}</button>
      </section>

      <section class="section">
        <div class="section-title">
          <h2>${t("leaderboard")}</h2>
          <span>${t("total")}</span>
        </div>
        <div class="leaderboard">
          ${leaders.map(renderLeaderRow).join("")}
        </div>
      </section>
    </section>
  `;
}

function renderLeaderRow(row) {
  const medal = row.rank <= 3 ? `<span class="medal">${row.rank}</span>` : `<span class="rank-number">${row.rank}</span>`;
  return `
    <div class="leader-row ${row.isUser ? "is-user" : ""}">
      ${medal}
      <div class="avatar">${row.isUser ? localized("你", "Y") : row.name.slice(0, 1)}</div>
      <div class="row-main">
        <strong>${row.isUser ? t("you") : row.name}</strong>
        <span>${localized(row.subZh, row.subEn)}</span>
      </div>
      <div class="row-count">
        <strong>${row.count}</strong>
        <span>${t("valid")}</span>
      </div>
    </div>
  `;
}

function renderCheckIn() {
  const mountain = selectedMountain();
  return `
    <section class="screen is-map fade-in" data-screen="checkin">
      <div class="topo"></div>
      <header class="map-header">
        <button class="icon-button" data-screen-target="detail" aria-label="${t("backToDetail")}">${icons.back}</button>
        <h1>${t("gpsCheckIn")}</h1>
        <span></span>
      </header>

      <div class="checkpoint-map" aria-label="${t("checkpointMap")}">
        <div class="radius-circle"></div>
        <div class="trail-line"></div>
        <div class="pin checkpoint">${icons.mountain}</div>
        <div class="pin user-pin"></div>
        <div class="distance-label">82m</div>
      </div>

      <div class="gps-panel">
        <div class="gps-row">${icons.target}<span>${t("gpsStatus")}</span><strong class="good">${t("good")}</strong></div>
        <div class="gps-row">${icons.pin}<span>${t("distanceToCheckpoint")}</span><strong class="good">82 m</strong></div>
        <div class="gps-row">${icons.accuracy}<span>${t("validRadius")}</span><strong class="good">150 m</strong></div>
        <div class="gps-row">${icons.clock}<span>${t("gpsAccuracy")}</span><strong class="good">18 m</strong></div>
      </div>

      <div class="photo-proof">
        <div class="proof-head">
          <div>
            <strong>${t("photoProof")}</strong>
            <span>${t("photoProofSub")}</span>
          </div>
          <span class="unlock-pill">${icons.check} ${t("validArea")}</span>
        </div>
        <div class="proof-actions" role="tablist" aria-label="${t("proofMethod")}">
          <button class="proof-option ${state.proofMode === "camera" ? "is-active" : ""}" data-proof-mode="camera" role="tab" aria-selected="${state.proofMode === "camera"}">
            ${icons.camera}
            <span>${t("takePhoto")}</span>
          </button>
          <button class="proof-option ${state.proofMode === "upload" ? "is-active" : ""}" data-proof-mode="upload" role="tab" aria-selected="${state.proofMode === "upload"}">
            ${icons.upload}
            <span>${t("uploadPhoto")}</span>
          </button>
        </div>
        <div class="stamp-preview ${state.proofMode === "upload" ? "is-upload" : ""}" style="--image: url('${mountain.image}')">
          <div class="stamp-brand">
            <span>${icons.mountain}</span>
            <strong>WildFrog</strong>
          </div>
          <div class="stamp-copy">
            <span>${t("validCheckIn")}</span>
            <strong>${mountainTitle(mountain)}</strong>
            <em>${mountain.height}m · ${regionLabel(mountain.region)} · ${localized(`第 ${mountain.myCheckins + 1} 次打卡`, `${mountain.myCheckins + 1} ${t("checkins")}`)}</em>
          </div>
        </div>
        <div class="proof-caption">
          <strong>${state.proofMode === "camera" ? t("cameraStamp") : t("uploadStamp")}</strong>
          <span>${state.proofMode === "camera" ? t("cameraCaption") : t("uploadCaption")}</span>
        </div>
        <button class="primary-action" data-action="complete-checkin">${icons.check} ${t("checkInNow")}</button>
        <div class="proof-lock-note">${icons.lock} ${t("lockNote")}</div>
      </div>

      <div class="safety-panel">
        ${icons.shield}
        <p>${t("safetyCopy")}</p>
      </div>
      <button class="secondary-action" data-screen-target="detail">${mountain.nameZh} ${t("details")}</button>
    </section>
  `;
}

function renderSuccess() {
  const mountain = selectedMountain();
  return `
    <section class="screen fade-in" data-screen="success">
      <div class="success-screen">
        <div class="stamp">${icons.check}</div>
        <div class="success-card">
          <h1>${mountain.nameZh} ${t("successTitle")}</h1>
          <p>${t("successCopy")}</p>
          <div class="success-stats">
            <div class="success-stat"><span>${t("validCheckins")}</span><strong>${state.didCheckIn ? mountain.myCheckins + 1 : mountain.myCheckins}</strong></div>
            <div class="success-stat"><span>${t("rank")}</span><strong>${userRankAfterCheckInText(mountain)}</strong></div>
            <div class="success-stat"><span>${t("nextRank")}</span><strong>1</strong></div>
          </div>
        </div>
        <button class="primary-action" data-screen-target="detail">${icons.mountain} ${t("backToMountain")}</button>
      </div>
    </section>
  `;
}

function renderExplore() {
  return `
    <section class="screen fade-in" data-screen="explore">
      <header class="screen-header">
        <div class="plain-title">
          <h1>${t("explore")}</h1>
          <p>${t("exploreSub")}</p>
        </div>
        <button class="icon-button" aria-label="${t("mapFilters")}">${icons.filter}</button>
      </header>

      <div class="explore-map">
        <div class="map-point">${icons.mountain}</div>
        <div class="map-point">${icons.mountain}</div>
        <div class="map-point">${icons.mountain}</div>
        <div class="map-point">${icons.target}</div>
        <div class="route-line"></div>
      </div>

      <section class="section">
        <div class="section-title">
          <h2>${t("nearbyRecords")}</h2>
          <span>HKT</span>
        </div>
        <div class="leaderboard">
          ${mountains.slice(0, 3).map((mountain) => renderRecordRow(mountain)).join("")}
        </div>
      </section>
    </section>
  `;
}

function renderRecords() {
  const activeMonth = activeCalendarMonth();
  const visibleArchive =
    state.calendarRange === "year"
      ? calendarMonths.filter((month) => month.key !== activeMonth.key)
      : calendarMonths.filter((month) => month.key !== activeMonth.key).slice(0, 1);
  const totalCalendarCheckins = calendarMonths.reduce((total, month) => total + month.entries.length, 0);

  return `
    <section class="screen records-screen fade-in" data-screen="records">
      <header class="screen-header">
        <div class="plain-title">
          <h1>${t("calendarRecords")}</h1>
          <p>${t("calendarRecordsSub")}</p>
        </div>
        <button class="icon-button" aria-label="${t("privacy")}">${icons.shield}</button>
      </header>

      ${renderCalendarRangeTabs()}

      <div class="calendar-stat-strip" aria-label="${t("monthSummary")}">
        <div class="calendar-stat">
          <strong>${activeMonth.entries.length}</strong>
          <span>${t("monthCheckins")}</span>
        </div>
        <div class="calendar-stat">
          <strong>${totalCalendarCheckins}</strong>
          <span>${t("totalValid")}</span>
        </div>
        <div class="calendar-stat">
          <strong>5</strong>
          <span>${t("streakDays")}</span>
        </div>
      </div>

      <section class="calendar-panel" aria-label="${t("photoCalendar")}">
        ${renderCalendarMonth(activeMonth)}
      </section>

      ${renderSelectedCalendarEntry()}

      <section class="section calendar-archive">
        <div class="section-title">
          <h2>${state.calendarRange === "year" ? t("yearOverview") : t("recentMonth")}</h2>
          <span>${t("privateCoordinates")}</span>
        </div>
        ${visibleArchive.map((month) => `<div class="calendar-panel is-compact">${renderCalendarMonth(month, true)}</div>`).join("")}
      </section>
    </section>
  `;
}

function renderCalendarRangeTabs() {
  const ranges = [
    ["today", t("today")],
    ["month", t("thisMonth")],
    ["year", t("thisYear")],
  ];

  return `
    <div class="calendar-tabs" role="tablist" aria-label="${t("photoCalendar")}">
      ${ranges
        .map(
          ([range, label]) => `
            <button class="calendar-tab ${state.calendarRange === range ? "is-active" : ""}" data-calendar-range="${range}" role="tab" aria-selected="${state.calendarRange === range}">
              ${label}
            </button>
          `
        )
        .join("")}
    </div>
  `;
}

function renderCalendarMonth(month, compact = false) {
  const entriesByDay = calendarEntriesByDay(month);
  const activeIndex = calendarMonths.findIndex((candidate) => candidate.key === month.key);
  const previousDisabled = compact || activeIndex >= calendarMonths.length - 1;
  const nextDisabled = compact || activeIndex <= 0;
  const weekdays = state.lang === "zh" ? ["周一", "周二", "周三", "周四", "周五", "周六", "周日"] : ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
  const spacerCells = Array.from({ length: month.startOffset }, (_, index) => `<span class="calendar-day-spacer" aria-hidden="true" data-spacer="${index}"></span>`).join("");
  const dayCells = Array.from({ length: month.days }, (_, index) => renderCalendarDayCell(month, index + 1, entriesByDay)).join("");

  return `
    <div class="calendar-month ${compact ? "is-compact" : ""}">
      <div class="calendar-month-head">
        <div>
          <span>${t("monthSummary")}</span>
          <h2>${localized(month.labelZh, month.labelEn)}</h2>
          <p>${localized(month.summaryZh, month.summaryEn)}</p>
        </div>
        ${
          compact
            ? ""
            : `
              <div class="calendar-month-tools">
                <button class="calendar-nav-button" data-calendar-month-shift="1" aria-label="${t("previousMonth")}" ${previousDisabled ? "disabled" : ""}>${icons.back}</button>
                <button class="calendar-nav-button" data-calendar-month-shift="-1" aria-label="${t("nextMonth")}" ${nextDisabled ? "disabled" : ""}>${icons.chevron}</button>
              </div>
            `
        }
      </div>
      <div class="calendar-weekdays">
        ${weekdays.map((weekday) => `<span>${weekday}</span>`).join("")}
      </div>
      <div class="calendar-grid">
        ${spacerCells}${dayCells}
      </div>
    </div>
  `;
}

function renderCalendarDayCell(month, day, entriesByDay) {
  const entry = entriesByDay.get(day);

  if (!entry) {
    return `
      <span class="calendar-day is-empty" aria-label="${day} ${t("calendarEmpty")}">
        <span class="calendar-day-number">${day}</span>
      </span>
    `;
  }

  const mountain = mountains.find((candidate) => candidate.id === entry.mountainId) || mountains[0];
  const selected = state.selectedCalendarEntryId === entry.id;
  const label = `${localized(entry.dateZh, entry.dateEn)} ${localized(entry.titleZh, entry.titleEn)}`;

  return `
    <button class="calendar-day has-photo is-${entry.tone} ${selected ? "is-selected" : ""}" data-calendar-day="${entry.id}" style="--image: url('${entry.image}')" aria-label="${escapeHtml(label)}" aria-pressed="${selected}">
      <span class="calendar-day-number">${day}</span>
      <span class="calendar-day-place">${state.lang === "zh" ? mountain.nameZh : mountain.nameEn}</span>
      <span class="calendar-day-count">${entry.count}</span>
    </button>
  `;
}

function renderSelectedCalendarEntry() {
  const entry = calendarEntryById(state.selectedCalendarEntryId);
  const mountain = mountains.find((candidate) => candidate.id === entry.mountainId) || mountains[0];
  const certificateMountainName = state.lang === "zh" ? mountain.nameZh : mountain.nameEn;
  const secondaryMountainName = state.lang === "zh" ? mountain.nameEn : mountain.nameZh;

  return `
    <section class="calendar-detail summit-certificate is-${entry.tone}" aria-label="${t("selectedCheckin")}" style="--image: url('${entry.image}')">
      <div class="certificate-brand">
        <span>${icons.mountain} ${t("summitCertificate")}</span>
        <span>${icons.check} ${t("proofSaved")}</span>
      </div>

      <div class="certificate-title">
        <span>${localized(entry.titleZh, entry.titleEn)}</span>
        <h2>${certificateMountainName}</h2>
        <strong>${t("summitCertificateTitle")}</strong>
      </div>

      <div class="certificate-meta">
        <div class="certificate-count">
          <span>${t("summitCount")}</span>
          <strong>${summitCountText(mountain.myCheckins)}</strong>
        </div>
        <div class="certificate-facts">
          <span>${t("mountainElevation")}: <strong>${mountain.height} m</strong></span>
          <span>${t("summitDate")}: <strong>${entry.dateISO}</strong></span>
        </div>
      </div>

      <div class="certificate-photo is-${entry.tone}" style="--image: url('${entry.image}')">
        <div class="photo-watermark-brand">
          <span class="photo-watermark-logo">${icons.mountain}</span>
          <div>
            <strong>WildFrog</strong>
            <span>${t("officialRecord")}</span>
          </div>
        </div>
        <div class="photo-watermark-seal" aria-hidden="true">${icons.mountain}</div>
        <div class="photo-watermark-info">
          <div>
            <span>${t("summitCertificate")}</span>
            <strong>${certificateMountainName}</strong>
            <em>${summitCountText(mountain.myCheckins)} · ${mountain.height}m · ${entry.dateISO}</em>
          </div>
          <span class="photo-watermark-rank">${sourceRankText(mountain)}</span>
        </div>
      </div>

      <div class="certificate-caption">
        <p>${localized(entry.noteZh, entry.noteEn)}</p>
      </div>

      <div class="certificate-footer">
        <div class="certificate-organizer">
          <strong>${t("activityMotto")}</strong>
          <span>${secondaryMountainName} · ${entry.time} · ${t("privateCoordinates")}</span>
        </div>
        <button class="certificate-qr" data-open-detail="${mountain.id}" aria-label="${t("verifyRecord")}">
          <span></span>
        </button>
      </div>

      <button class="secondary-action" data-open-detail="${mountain.id}">${icons.mountain} ${t("viewMountain")}</button>
    </section>
  `;
}

function renderHistoryRow(item) {
  const mountain = mountains.find((candidate) => candidate.id === item.mountainId) || mountains[0];
  return `
    <button class="history-row" data-open-detail="${mountain.id}">
      <img class="record-thumb" src="${mountain.image}" alt="" />
      <div class="row-main">
        <strong>${mountainTitle(mountain)}</strong>
        <span>${localized(item.dateZh, item.dateEn)} · ${item.time}</span>
      </div>
      <div class="status-pill">${localized(item.statusZh, item.statusEn)} ${icons.check}</div>
    </button>
  `;
}

function renderProfile() {
  return `
    <section class="screen fade-in" data-screen="profile">
      <header class="screen-header">
        <span></span>
        <div class="header-actions">
          ${renderLanguageToggle()}
          <button class="icon-button" aria-label="${t("settings")}">${icons.settings}</button>
        </div>
      </header>

      <div class="profile-top">
        <div class="profile-photo">山</div>
        <div>
          <h1>山野之心</h1>
          <p>${icons.pin} ${t("profileLocation")}</p>
        </div>
      </div>

      <div class="profile-card">
        <div class="profile-stats">
          <div class="profile-stat"><strong>86</strong><span>${t("totalValid")}</span></div>
          <div class="profile-stat"><strong>14</strong><span>${t("mountainsVisited")}</span></div>
          <div class="profile-stat"><strong>13</strong><span>${t("mostVisited")}</span></div>
        </div>
      </div>

      <section class="section">
        <div class="section-title">
          <h2>${t("topMountainRecords")}</h2>
          <span>${t("total")}</span>
        </div>
        <div class="leaderboard">
          ${mountains.map(renderRecordRow).join("")}
        </div>
      </section>

      <section class="section">
        <div class="privacy-row">
          <div>
            <strong>${t("privateProfile")}</strong>
            <span>${t("privateProfileCopy")}</span>
          </div>
          <button class="switch" aria-label="${t("privateProfileEnabled")}"><span></span></button>
        </div>
      </section>
    </section>
  `;
}

function renderRecordRow(mountain) {
  return `
    <button class="record-row" data-open-detail="${mountain.id}">
      <img class="record-thumb" src="${mountain.image}" alt="" />
      <div class="row-main">
        <strong>${mountainTitle(mountain)}</strong>
        <span>${mountain.height}m · ${regionLabel(mountain.region)}</span>
      </div>
      <div class="row-count">
        <strong>${mountain.myCheckins}</strong>
        <span>${t("checkins")}</span>
      </div>
    </button>
  `;
}

function renderNav() {
  const items = [
    ["home", t("home"), icons.mountain],
    ["explore", t("explore"), icons.compass],
    ["checkin", t("checkIn"), icons.target, true],
    ["records", t("records"), icons.records],
    ["profile", t("profile"), icons.user],
  ];

  return `
    <nav class="bottom-nav" aria-label="${t("navPrimary")}">
      ${items
        .map(([screen, label, icon, primary]) => {
          const active = state.screen === screen || (screen === "checkin" && state.screen === "success");
          if (primary) {
            return `
              <button class="nav-item is-primary ${active ? "is-active" : ""}" data-screen-target="checkin" aria-label="${label}">
                <span class="nav-bubble">${icon}</span>
                <span>${label}</span>
              </button>
            `;
          }
          return `
            <button class="nav-item ${active ? "is-active" : ""}" data-screen-target="${screen}" aria-label="${label}">
              ${icon}
              <span>${label}</span>
            </button>
          `;
        })
        .join("")}
    </nav>
  `;
}

function bindEvents() {
  document.querySelectorAll("[data-action='toggle-language']").forEach((button) => {
    button.addEventListener("click", () => {
      state.lang = state.lang === "zh" ? "en" : "zh";
      render();
    });
  });

  document.querySelectorAll("[data-screen-target]").forEach((button) => {
    button.addEventListener("click", () => {
      state.screen = button.dataset.screenTarget;
      render();
    });
  });

  document.querySelectorAll("[data-open-detail]").forEach((button) => {
    button.addEventListener("click", () => {
      state.selectedMountainId = button.dataset.openDetail;
      state.screen = "detail";
      render();
    });
  });

  document.querySelectorAll("[data-region]").forEach((button) => {
    button.addEventListener("click", () => {
      state.region = button.dataset.region;
      state.homeListLimit = homeListChunkSize;
      render();
    });
  });

  document.querySelectorAll("[data-home-sort]").forEach((button) => {
    button.addEventListener("click", () => {
      state.homeSort = button.dataset.homeSort;
      state.homeListLimit = homeListChunkSize;
      render();
    });
  });

  document.querySelectorAll("[data-map-size]").forEach((button) => {
    button.addEventListener("click", () => {
      state.mapHeight = button.dataset.mapSize === "large" ? mapHeightRange.large : mapHeightRange.compact;
      render();
    });
  });

  const loadMoreButton = document.querySelector("[data-load-more]");
  if (loadMoreButton) {
    loadMoreButton.addEventListener("click", () => {
      state.homeListLimit += homeListChunkSize;
      render();
    });
  }

  document.querySelectorAll("[data-proof-mode]").forEach((button) => {
    button.addEventListener("click", () => {
      state.proofMode = button.dataset.proofMode;
      render();
    });
  });

  document.querySelectorAll("[data-calendar-range]").forEach((button) => {
    button.addEventListener("click", () => {
      state.calendarRange = button.dataset.calendarRange;
      if (state.calendarRange === "today") {
        const currentMonth = calendarMonths[0];
        state.calendarMonthKey = currentMonth.key;
        state.selectedCalendarEntryId = currentMonth.entries.at(-1).id;
      }
      render();
    });
  });

  document.querySelectorAll("[data-calendar-month-shift]").forEach((button) => {
    button.addEventListener("click", () => {
      const currentIndex = calendarMonths.findIndex((month) => month.key === state.calendarMonthKey);
      const nextMonth = calendarMonths[currentIndex + Number(button.dataset.calendarMonthShift)];

      if (nextMonth) {
        state.calendarMonthKey = nextMonth.key;
        state.selectedCalendarEntryId = nextMonth.entries.at(-1).id;
        render();
      }
    });
  });

  document.querySelectorAll("[data-calendar-day]").forEach((button) => {
    button.addEventListener("click", () => {
      state.selectedCalendarEntryId = button.dataset.calendarDay;
      state.calendarMonthKey = state.selectedCalendarEntryId.slice(0, 7);
      render();
    });
  });

  const searchInput = byId("searchInput");
  if (searchInput) {
    searchInput.addEventListener("input", (event) => {
      state.query = event.target.value;
      state.homeListLimit = homeListChunkSize;
      render();
      const nextInput = byId("searchInput");
      if (nextInput) {
        nextInput.focus();
        nextInput.setSelectionRange(nextInput.value.length, nextInput.value.length);
      }
    });
  }

  const checkinButton = document.querySelector("[data-action='complete-checkin']");
  if (checkinButton) {
    checkinButton.addEventListener("click", () => {
      state.didCheckIn = true;
      state.screen = "success";
      render();
    });
  }

  bindMapResize();
}

function bindMapResize() {
  const handle = document.querySelector("[data-map-resize-handle]");
  if (!handle) return;

  let isDragging = false;
  let pointerId = null;
  let startY = 0;
  let startHeight = state.mapHeight;

  const setLiveHeight = (height) => {
    state.mapHeight = clampMapHeight(height);
    const map = handle.closest(".map-overview");
    if (map) map.style.setProperty("--map-height", `${state.mapHeight}px`);
    handle.setAttribute("aria-valuenow", String(state.mapHeight));
  };

  handle.addEventListener("pointerdown", (event) => {
    isDragging = true;
    pointerId = event.pointerId;
    startY = event.clientY;
    startHeight = state.mapHeight;
    try {
      handle.setPointerCapture(pointerId);
    } catch {
      pointerId = event.pointerId;
    }
    document.body.classList.add("is-map-resizing");
    event.preventDefault();
  });

  handle.addEventListener("pointermove", (event) => {
    if (!isDragging || event.pointerId !== pointerId) return;
    setLiveHeight(startHeight + event.clientY - startY);
  });

  const finishDrag = (event) => {
    if (!isDragging || event.pointerId !== pointerId) return;
    isDragging = false;
    document.body.classList.remove("is-map-resizing");
    if (pointerId !== null && handle.hasPointerCapture(pointerId)) handle.releasePointerCapture(pointerId);
    pointerId = null;
  };

  handle.addEventListener("pointerup", finishDrag);
  handle.addEventListener("pointercancel", finishDrag);

  handle.addEventListener("keydown", (event) => {
    if (event.key !== "ArrowUp" && event.key !== "ArrowDown") return;
    event.preventDefault();
    setLiveHeight(state.mapHeight + (event.key === "ArrowDown" ? 24 : -24));
  });
}

function escapeHtml(value) {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

render();
