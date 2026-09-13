# فئات وتصنيفات الأماكن والخدمات في مدينة السادات (inRide Places System)

دليل شامل لكافة فئات وتصنيفات الأماكن والخدمات في قاعدة بيانات تطبيق **inRide** الخاصة بمدينة السادات (محافظة المنوفية)، وتضم **25 فئة تجارية وخدمية رئيسية**، بالإضافة إلى **التصنيفات الجغرافية للمناطق السكنية والصناعية** و**التصنيفات الفرعية**.

---

## 1. الفئات الـ 25 الرئيسية للخدمات والمحلات (`category`)

| # | المعرف البرمجي (`id`) | الاسم بالعربي | الاسم بالإنجليزي | التصنيفات الفرعية (`sub_categories`) | كلمات البحث الدلالية (`keywords`) |
|---|---|---|---|---|---|
| 1 | `supermarket` | **سوبر ماركت وبقالات** | Supermarkets & Groceries | `hypermarket`, `supermarket`, `grocery`, `greengrocer`, `dairy_ice_cream`, `discount_store` | سوبر ماركت، بقالة، هايبر، مواد غذائية، خضار وفاكهة، تموين، ميني ماركت |
| 2 | `restaurant` | **مطاعم ومأكولات** | Restaurants & Food | `fast_food`, `grill`, `pizza`, `crepe_waffle`, `koshary`, `burger`, `hawawshi`, `seafood`, `syrian`, `oriental`, `oriental_mandi` | مطعم، مطاعم، اكل، وجبات، مشويات، بيتزا، كريب، شاورما، اسماك، كشري، برجر، ساندوتشات |
| 3 | `cafe` | **كافيهات ومقاهي** | Cafes & Coffee Shops | `coffee_shop`, `traditional_cafe`, `family_cafe`, `lounge`, `juice_bar`, `bakery_cafe` | كافيه، كافيهات، مقهى، قهوة، كوفي شوب، لاونج، عصائر، قعدة، شاي، مشروبات |
| 4 | `pharmacy` | **صيدليات ومستلزمات طبية** | Pharmacies & Drugstores | `community_pharmacy`, `community_pharmacy_24h`, `chain_pharmacy` | صيدلية، صيدليات، دواء، علاج، ادوية، صيدلية 24 ساعة، فيتامينات، مستلزمات طبية |
| 5 | `clothing` | **ملابس وأزياء** | Clothing & Fashion | `menswear`, `womenswear`, `sportswear`, `shoes`, `fashion`, `department_store` | ملابس، ازياء، بدل، فساتين، احذية، جزم، شنط، ملابس اطفال، رجالي، حريمي، بوتيك |
| 6 | `electronics` | **موبايلات وإلكترونيات** | Electronics & Mobiles | `mobile_phones`, `telecom`, `home_appliances`, `electrical_supplies` | موبايل، هواتف، تليفونات، صيانة موبايل، كمبيوتر، لابتوب، الكترونيات، اجهزة كهربائية، شاشات |
| 7 | `butcher` | **جزارات ولحوم ودواجن** | Butchers & Poultry | `butcher`, `poultry` | جزار، جزارة، لحوم، لحمة، لحم طازج، دواجن، فراخ، طيور، اسماك طازجة، كندوز |
| 8 | `bakery` | **مخابز وحلوانيات** | Bakeries & Pastries | `bakery`, `pastry_shop`, `baladi_bread` | مخبز، مخابز، فرن، عيش، حلواني، حلويات، كيك، تورته، مخبوزات، فينو، باتيه، بسبوسة |
| 9 | `general_retail` | **محلات عامة ومكتبات** | General Retail & Stationery | `stationery`, `houseware`, `toys_gifts`, `hardware_tools` | ادوات منزلية، مكتبة، هدايا، العاب اطفال، اثاث، مفروشات، خردوات، بلايستيشن |
| 10 | `maintenance` | **الصيانة والخدمات الفنية** | Maintenance & Crafts | `plumbing`, `appliance_repair` | صيانة، سباك، سباكة، كهربائي، نجار، نجارة، تكييف، الوميتال، زجاج، ورش، تصليح |
| 11 | `automotive` | **السيارات وقطع الغيار** | Automotive & Car Services | `car_service`, `tires_alignment`, `car_wash`, `car_dealership` | قطع غيار، ميكانيكي، عفشة، كاوتش، اطارات، بطاريات، زيوت، غيار زيت، مغسلة سيارات |
| 12 | `gas_station` | **محطات الوقود والغاز** | Gas & Fuel Stations | `gas_station`, `cng_station` | بنزين، بنزينة، محطة بنزين، محطة وقود، سولار، غاز طبيعي، شحن كهرباء |
| 13 | `medical` | **الخدمات الطبية والمستشفيات** | Medical & Healthcare | `general_hospital`, `specialized_hospital`, `clinic`, `laboratory`, `radiology_lab` | مستشفى، عيادة، دكتور، طبيب، معمل تحاليل، اشعة، اسنان، مركز طبي، علاج طبيعي |
| 14 | `education` | **التعليم والمدارس والمعاهد** | Education & Schools | `school`, `college`, `institute`, `university_hq` | مدرسة، مدارس، جامعة، كلية، معهد، حضانة، سنتر، دروس، مركز تعليمي، اكاديمية |
| 15 | `mall` | **المولات والمراكز التجارية** | Malls & Shopping Centers | `shopping_mall`, `commercial_center` | مول، مولات، سيتي مول، مركز تجاري، سوق، اسواق، مجمع تجاري |
| 16 | `finance` | **البنوك والخدمات المالية** | Banks & Financial Services | `bank` | بنك، بنوك، atm، صراف الي، صرافة، تحويل اموال، فودافون كاش، فوري، وي باي |
| 17 | `shipping` | **الشحن والتوصيل والبريد** | Shipping & Logistics | `courier` | شحن، توصيل، شركة شحن، مكتب شحن، ارامكس، بوسطة، طرود، شحنات |
| 18 | `hotel` | **الفنادق والإقامة** | Hotels & Accommodation | `hotel`, `resort_hotel` | فندق، فنادق، شقق فندقية، اقامة، سكن فندقي |
| 19 | `events` | **القاعات والمناسبات** | Event & Wedding Halls | `wedding_hall`, `banquet_hall` | قاعة، قاعات، قاعة افراح، مناسبات، افراح، حفلات، سيشن |
| 20 | `sports` | **الرياضة والنوادي والجيم** | Sports, Fitness & Gyms | `gym`, `sports_club` | جيم، نادي، نوادي، ملعب، ملاعب، مركز شباب، كرة قدم، سباحة |
| 21 | `corporate` | **الشركات والمكاتب** | Corporate & Offices | `business_services`, `business_association` | شركة، شركات، مكتب، عقارات، تسويق عقاري، استشارات |
| 22 | `factory` | **المصانع والمنشآت الصناعية** | Factories & Industrial | `ceramics_industry`, `cables_industry`, `heavy_industry`, `food_industry`, `pharma_industry` | مصنع، مصانع، شركة صناعية، منطقة صناعية، صناعة، مطورين |
| 23 | `religious` | **المساجد والكنائس ودور العبادة** | Mosques & Churches | `mosque`, `church` | مسجد، مساجد، جامع، كنيسة، كنائس، دار عبادة، صلاة الجمعة |
| 24 | `government` | **الخدمات والهيئات الحكومية** | Government & Civic Services | `city_hall`, `police`, `traffic_unit`, `passport_office`, `post_office`, `government_complex` | مجلس المدينة، جهاز المدينة، سجل مدني، مرور، قسم شرطة، بريد، شهر عقاري، محكمة |
| 25 | `transport` | **المواصلات والمواقف** | Transportation & Bus Terminals | `bus_terminal`, `microbus_stand`, `intercity_bus` | موقف، مواقف، ميكروباص، محطة اتوبيس، موقف العاشر، موقف السابعة، سوبرجيت، مواصلات |

---

## 2. الفئات الجغرافية والمناطق العمرانية (`place_type` / `urban_zones`)

1. **`residential` (المناطق والأحياء السكنية)**:
   - المناطق السكنية المرقمة من **المنطقة الأولى (1)** حتى **المنطقة السادسة والثلاثين (36)**.
   - الأحياء السكنية: إسكان المستقبل، دار مصر، سكن مصر، المجاورات، حي النرجس، الزهور، الريحان، الروضة.
2. **`industrial` (المناطق الصناعية)**:
   - المناطق الصناعية من **الأولى حتى الثامنة (المناطق 1 - 8)** + منطقة المطورين ومجمع الصناعات.
3. **`university` (المجمعات الجامعية والكليات)**:
   - جامعة مدينة السادات، معهد الهندسة الوراثية، مجمع كليات الحي السادس، المعاهد الأكاديمية والبحثية.

---

## 3. قائمة التصنيفات الفرعية الشاملة (`sub_category` - 91 تصنيفاً)

- **المطاعم والأغذية:**
  `fast_food`, `grill`, `pizza`, `crepe_waffle`, `koshary`, `burger`, `hawawshi`, `seafood`, `syrian`, `oriental`, `oriental_mandi`, `oriental_fast_food`, `juice_bar`, `dairy_ice_cream`, `pastry_shop`, `bakery`, `baladi_bread`
- **الكافيهات والمقاهي:**
  `coffee_shop`, `traditional_cafe`, `family_cafe`, `lounge`, `bakery_cafe`
- **التسوق والبقالة:**
  `hypermarket`, `supermarket`, `grocery`, `greengrocer`, `discount_store`, `department_store`, `shopping_mall`, `commercial_center`, `butcher`, `poultry`
- **الملابس والموضة:**
  `menswear`, `womenswear`, `sportswear`, `shoes`, `fashion`
- **الإلكترونيات والاتصالات:**
  `mobile_phones`, `telecom`, `home_appliances`, `electrical_supplies`
- **الخدمات الطبية:**
  `general_hospital`, `specialized_hospital`, `clinic`, `laboratory`, `radiology_lab`, `community_pharmacy`, `community_pharmacy_24h`, `chain_pharmacy`
- **السيارات والمحطات:**
  `car_service`, `tires_alignment`, `car_wash`, `car_dealership`, `gas_station`, `cng_station`
- **المواصلات:**
  `bus_terminal`, `microbus_stand`, `intercity_bus`
- **المباني الحكومية والأمنية:**
  `city_hall`, `police`, `traffic_unit`, `passport_office`, `post_office`, `government_complex`
- **دور العبادة:**
  `mosque`, `church`
- **التعليم:**
  `school`, `college`, `institute`, `university_hq`
- **المال والأعمال:**
  `bank`, `business_services`, `business_association`
- **الرياضة والترفيه:**
  `gym`, `sports_club`, `wedding_hall`, `banquet_hall`
- **الفنادق:**
  `hotel`, `resort_hotel`
- **الصيانة والتجزئة:**
  `plumbing`, `appliance_repair`, `hardware_tools`, `houseware`, `stationery`, `toys_gifts`, `courier`
- **المصانع:**
  `ceramics_industry`, `cables_industry`, `heavy_industry`, `food_industry`, `pharma_industry`
