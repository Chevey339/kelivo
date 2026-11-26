// Chinese prose frequency bands, derived from Unicode 15.0 Unihan kFrequency.
// Each simplified variant inherits the more frequent of its own and its
// traditional form’s rank (kSimplifiedVariant). Keep bands 1–4, sorted by
// code point. We need a coarse language prior, not a vocabulary or dictionary.
// Source: https://github.com/unicode-org/unicodetools/tree/main/unicodetools/data/ucd/15.0.0/Unihan
//
// UNICODE LICENSE V3
//
// COPYRIGHT AND PERMISSION NOTICE
//
// Copyright © 1991-2026 Unicode, Inc.
//
// NOTICE TO USER: Carefully read the following legal agreement. BY
// DOWNLOADING, INSTALLING, COPYING OR OTHERWISE USING DATA FILES, AND/OR
// SOFTWARE, YOU UNEQUIVOCALLY ACCEPT, AND AGREE TO BE BOUND BY, ALL OF THE
// TERMS AND CONDITIONS OF THIS AGREEMENT. IF YOU DO NOT AGREE, DO NOT
// DOWNLOAD, INSTALL, COPY, DISTRIBUTE OR USE THE DATA FILES OR SOFTWARE.
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of data files and any associated documentation (the "Data Files") or
// software and any associated documentation (the "Software") to deal in the
// Data Files or Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, and/or sell
// copies of the Data Files or Software, and to permit persons to whom the
// Data Files or Software are furnished to do so, provided that either (a)
// this copyright and permission notice appear with all copies of the Data
// Files or Software, or (b) this copyright and permission notice appear in
// associated Documentation.
//
// THE DATA FILES AND SOFTWARE ARE PROVIDED "AS IS", WITHOUT WARRANTY OF ANY
// KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT OF
// THIRD PARTY RIGHTS.
//
// IN NO EVENT SHALL THE COPYRIGHT HOLDER OR HOLDERS INCLUDED IN THIS NOTICE
// BE LIABLE FOR ANY CLAIM, OR ANY SPECIAL INDIRECT OR CONSEQUENTIAL DAMAGES,
// OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
// WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
// ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THE DATA
// FILES OR SOFTWARE.
//
// Except as contained in this notice, the name of a copyright holder shall
// not be used in advertising or otherwise to promote the sale, use or other
// dealings in these Data Files or Software without prior written
// authorization of the copyright holder.

int chineseProseFrequency(int rune) => _frequency[rune] ?? 0;

final _frequency = <int, int>{
  for (final rune
      in ('一上下不个中为么之也了于交人他以们会但何你來信個們出到前去发可同后吗和問嗎因国國在地多大天好如子学學定家对對小就工年当很'
              '後得心想意成我所提文新於无时是時最會有本机来果機沒没法為無然爲现現生用电當發的看真知站章而能自要訊說請讯说请过还这這過道'
              '還那都问電麼')
          .runes)
    rune: 4,
  for (final rune
      in ('万三与专且世业东两並主久义乎乐书买事二五些什今从代件价任份传似位住体作使便保修候做備傳像價儿元兄先光兒党入內全兩八公六共'
              '关兴其内再写军决几凤凰分则別利别制則力办功加务动動務化北区區十华单南卡即却卻原参參又及友反取受变口另叫台号吃各合名向否吧'
              '听告员呢呵命品哈員哪啊啦喔喜單器四回图圖场型城基報場士声处备外夢太央失头奇女她妳始字孩它安完实室容實寫将將專少山差己已市'
              '师希带師帮帶常幫平并幾应度建开式引弟张張強强录形影從必快念怎思性怪总您情愛感應或战戰手才打找把投报拿持指换掉接換支收改放'
              '政故教数整數料方日明星更書曾月朋服望期未权李東板林标校样格案档梦業樂標樣檔權次欢歌歡正此死每比民气氣水求決活流海清湾满滿'
              '灣点爱片版物特独猫獨王玩班球理由男画界留畫白目直相眼着研破确確社神种科程種究空立竹笑第等算管类系級組結給統經網線總级线组'
              '经结给统缐网美義老考者耶联聯聲聽脑腦至臺與興般色花若英華萬著處號虽行表被装裝裡西見視覺觀见观视觉解言計討記設許訴試話該認'
              '語誰課論講謝識議讀變讓计认讨让议记讲许论设识诉试话该语读课谁谢象貓買費資賽费资赛走起超跟路身車軍較轉车转较辦边运近进远连'
              '迷选通速造連進運遠選邊部里重量金錄錢錯钱错長长門開間關门间队阿陈除陳隊难雖難需非面音頭題類题風风飛飞馬驗马验體高鳳黃黄點'
              '黨龍龙𢧐𧹒𫔭')
          .runes)
    rune: 3,
  for (final rune
      in ('七严丽举九习乱亂争云亚亞亦产享亮亲仁介仍仔付令众优伟伤低佛佳例供依係俊倒值假偉停傷優充克免兰兵具典养况冷准击刀切划列刘刚'
              '创初判刻剑剛剧創劃劇劉劍助努势勝勢包医千升午半协協卖博卫印厂历压双古句只史右叶司吉君含启吳吴呀呆呜周味呼哇响哥哦唉售唱商'
              '啟啥啰善嗚嗯嘛嘻嘿嚴囉团园園團土圣均坏坐块垒執堂堆塊境增壓壘壞复夜够夠夫奏套妈妹姐委威媽存守宗官宜宝客宣害宿寄密寶寻导封'
              '射尋導尔尚尤尽局居展属屬岁左巧巴布帝幕干幸幹广底店府座康廠廣异弄弹彈归彩往征待律復微徵德忆志忘忙怀态怕急恋恐息恶悲惜惡愿'
              '態慢慧慮憶懂懷戀戏戲房扁执承技抓护抱担拉招拜择按据授排控推援搞播擇擊擔據攻效救敗敢断斯斷施旁族既旧早易春昨显晚普景智暗暴'
              '曲木术杀杂条杨极构架某查树核根梅條检棒楊楚極楼概榮構樓模樹檢欣欲歉止步武歲歷歸段殺母毒毕毛永汉江油治況波注洋派测济浪消深'
              '温測湖源準溫演漢漫激濟灌火灯灵烂烦热照煩熱燈營爛爭父爽爾牌牛状狀狂狗猪率环琴環甚產産田甲畢異疑病痛登百皆皮益盡省眾睡督石'
              '码硬碟碼磁示礼票福禮离称稱穿突竟笔筆答策签简節篇簡簽精紀約紅純紙素細紹終絕絡維緣編練繼續红约纪纯纸练细终绍络绝继续维编缘'
              '缺罗罢罪置罵罷羅群習翻聊职聖聞職肉育背胜脚脸腳臉致舉舊舞良艺节苦草荐荣莫萤营落葉蓝薦藍藝蘭虎虑蛮螢蠻血衆術衛补補製規親规'
              '角訓註評詞詳誠誤調談諸謂證警護训证评词诚详误诸调谈谓豬負責貴貼賞賣質负责败质贴贵赏赵赶越趕趙趣足跑跳軟載輕輯輸软轻载辑输'
              '达迎述追退送适逢週遇遊達適郭配酒醫释釋野銘鍵鐘鐵钟铁铭键闻防阳阵附际陆限院陣险陸陽随際隨險隻雄集雙雜離雨雲雷靈青静靜靠響'
              '項順須預領願顧顯项顺须顾预领養餐館馆首香騎骂骑鬼魔魚鱼鳥鸟麗麻黑𫖸𬞕𬣣')
          .runes)
    rune: 2,
  for (final rune
      in ('丁丈丌丑丙丝丟丢丰串临丸丹乃乌乏乔乖乘乙乡乾予亏互井亡亨京亿仅仇仙仪仰仲企伊伍休伙伦伯估伴伸佈佔余佩侠侦侧侨侯侵促俗俠俱'
              '倍倚借倫倾偏健側偵偶偷傑傢傲傻傾僅僑儀億儒儘允兇兔兮兼兽冊册冒农冠冬冰冲凉凌减凝凡凭凯凱函刊删刪刷刺剩剪副割劝劫励劲劳勁'
              '勇勉勒勞勤勵勸勿卒危卷厅厉厌厚厭厲县叔召叭叹吊吐吓吕吝吟吵吸吹吾呂咖咦咧咪咬咱哀哉哎哩哭哲唐唬唯唷唸啡啪喂喇喊喝喬喵喷嗨'
              '嘆嘉嘗嘴噴嚇困围固圆圈圍圓圾址坚坜坡坤坦坪垃域培堅堕堪塔塗塞填塵墙墨墮壁壢壮壯壳壽夏夕夥夸夹夺夾奈奉奋契奔奖奥奧奪奮奶妇'
              '妙妥妨妮妻姆姊姑姓姿娃娘婆婚婦媒嫌孔孙孝孟季孤孫宁宇宋宏宙审宪宫宮宽宾寂富寒寝寞察寢寧審寬寿尊尖尘尝尺尼尾屁层屆届屋屏屠'
              '層岂岚岛岭岸峰島崇嵐嶺川州巡巨巫巷币帅帐帥席帳帽幅幣幻幼幽庄庆床序库废庫庭庸廉廖廢廳延廷弃弘弥弦弯弱彌彎彥彦彬彭彰役彻彼'
              '径徐徑徒徹忌忍忠忧忽怒怖怜怡怨恆恒恢恥恨恩恭恰恼悅悉悔悟悠悦悶惊惑惠惧惨惯惱惹愁愈愉愚慈慕慘慣慰慶慾憂憐憑憲憾懒懶懼戒截'
              '戴戶户扇托扣扩扫扬扯扰批抄抗折抛抢披抬抵抹抽拆拋拍拒拔拖拟拥拨括拳拼拾挂挑挖挡挤挥振挺捐捕损捡捨捲捷掃掌掛採探措描插揚握'
              '揮損搖搬搭搶摄摆摇摘摩摸撐撑撞撥撿擁擋操擎擠擦擬擴擺擾攝敌敏敝散敦敬敵斋斗旅旋旗旦旭昇昌昏映昭晓晨晴晶暂暑暖暫曉曰曼替朗'
              '朝末朱朵材村杜束杯杰松析枝枢枪枫柏染柔柳栏桃桌桑桥梁梯械棄棋棚森椅植椰楓榜槍樞横橋橫欄欧欺欽款歐殊残殘殼毀毁毅毫氏汝池污'
              '汤汪汽沈沉沖沙沟沧河沿泉泡泥泪泰泳泽洁洗洛洞洩洪洲洽浅浓浩浮涂涉涛涨涯液涵涼淑淚淡淨混淺渐減渡港游湯溝溪滄滅滋滑滚滥滴滾'
              '漂漏漲漸潔潛潜潮澤濃濤濫灭灰災灾炉炎炮炸烈烏烟烤烧焦煙煞熊熟燃燒爆爐爬爵爷爸爺牆牙牠牧牲牵牺牽犧犯犹狐狠狮狱狼猛猜献猶獄'
              '獅獎獲獸獻玄玉玛玫玲珍珠琪瑜瑞瑪瑰瓜瓦瓶甘甜申略番疏疗疯疼痕痴瘋療癡皇盃监盖盗盘盛盜盟監盤盼盾眉眠睛瞧瞭矛矣短砂砍砲础硕'
              '碍碎碗碧碩碰磨礎礙祖祝祥祸禁禅禍禪秀私秋秒秘租秤秦积移稅稍税稣稳稿穌積穩穷穹窗窝窩窮竞童端競笛符笨筋筑筹箭箱範築篮籃籌籍'
              '米粉粗糊糕糟納紛索紧紫累絲綜綠綱緊緒緩縣縮縱績繁織繞繪繳纲纳纵纷织绕绘绩绪综绿缓缩缴缸罚罰署羊羞羽翁翔翘翹翼耀耍耐耗耳耻'
              '聚聪聰肚股肥肩肯胆胎胖胞胡胸脆脫脱腰腿膽臥臨臭舍舒舟航舰船艦艾芬芳苍苏范茫茶荒药荷莉莊莎莱莲获菜菩菲萊萧萨葛蒋蒙蒼蓋蓮蔡'
              '蔣蕭薄薩薪藉藏藤藥蘇虚虛虧虫蛋蛙蜂蜜蝶融蟲蟹蠍街衝衡衣袋裁裂裕裤複褲覆覽览触觸訂託訪証詢詩誇誉誌誓誕誼諒諾謀譜譯譽讚订讬'
              '访译诗诞询诺谅谊谋谱谷豆豈豐豪貌貝貞財貢貨貪貫賀賓賜賢賤賦賭賴賺購贈贊贏贝贞贡财贤货贪购贯贱贺赋赌赐赖赚赞赠赢赤趋趨跃跌'
              '距跡踏踢踪蹟蹤躍躲軌軒輔輛輝輩輪轟轨轩轮轰辅辆辈辉辛辞辨辩辭辯辱農迁迅迈违迟迪迫迴迹逃逆逊透逐途逛逝逸逻逼遍違遗遙遜遥遭'
              '遲遷遺避邀邁邏邦邪邮邱邻郁郎郑郵鄉鄭鄰酷酸醉醒醜采針釣鈴銀銳銷鋒鋼錦鍋鍾鎖鎮鏡鑑针钓钢钦铃银销锁锅锋锐锦锺镇镜閃閉閒閣閱'
              '闆闊闡闪闭闲闷闹阁阅阐阔阴阶阻陀降陪陰陵陷隆階隐隔障隱雅雞雪雳零雾震霧露霸霹靂靖革鞋韓韩韵韻頁頂頑頓頗頻顆額顏页顶顽顿颇'
              '频颗颜额飄飘食飯飲飽飾餅餘饭饮饰饱饼馀駐駕駛騙騷驅驚驱驶驻驾骗骚骨髮鬆鬥鬧鬱魂魅魯鮮鲁鲜鳴鴻鵝鷹鸡鸣鸿鹅鹰鹿麥麦麵黎默鼓'
              '鼠鼻齊齋齐齒齡齿龄龜龟𧿛𬤮𬮳𰵧𰾫𱂐')
          .runes)
    rune: 1,
};
