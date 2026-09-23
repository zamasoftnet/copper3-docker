/<\/cid-fonts>/i\
		<!-- Docker配布版: 組み込みNotoと利用者追加フォントを個別に走査する。 -->\
		<font-dir dir="truetype/Noto_Sans_JP" types="cid-identity embedded" />\
		<font-dir dir="truetype/Noto_Serif_JP" types="cid-identity embedded" />\
		<font-dir dir="truetype/user" types="cid-identity embedded" />
# 総称書体の和文を Noto にする。欧文は従来どおり Times-Roman・Helvetica、Noto に無い文字は AJ14 などへ落ちる。
# Noto は埋め込み型なので、default.properties の output.pdf.fonts.policy が embedded を含むときだけ選ばれる
# (機能限定版では方針を変えられないので、従来どおり Mincho・Gothic になる)。
# monospace は Noto Sans JP の欧文が等幅でないので変えない。
s|<serif font-family="Times-Roman,Mincho,|<serif font-family="Times-Roman,Noto Serif JP,Mincho,|
s|<sans-serif font-family="Helvetica,Gothic,|<sans-serif font-family="Helvetica,Noto Sans JP,Gothic,|
s|<fantasy font-family="Comic-Sans-MS,Gothic,|<fantasy font-family="Comic-Sans-MS,Noto Sans JP,Gothic,|
s|<cursive font-family="Comic-Sans-MS,Mincho,|<cursive font-family="Comic-Sans-MS,Noto Serif JP,Mincho,|
