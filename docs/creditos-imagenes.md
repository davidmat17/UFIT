# Créditos de las imágenes

Las fotos de las máquinas del catálogo (RF5) son fotos de referencia. No son del gimnasio de la UIS. Catorce vienen de [Wikimedia Commons](https://commons.wikimedia.org) y tienen licencia libre. La de la bicicleta reclinada es la excepción, como se explica más abajo.

Para que el catálogo cargue rápido, cada foto se redimensionó a 600 px por el lado más largo y se comprimió en JPEG. Así quedaron entre 28 y 81 KB, unos 750 KB las quince. Ese es el único cambio que se les hizo. Los archivos están en `supabase/fotos-maquinas/` y se sirven desde el bucket público `maquinas` del Storage de Supabase. Las direcciones se cargan en la base con `supabase/migraciones/006_rf5_fotos_en_storage.sql`. Las migraciones 004 y 005 son las versiones anteriores, que apuntaban directamente a Wikimedia.

La foto de la bicicleta reclinada es la excepción: no se encontró una con licencia libre, así que se usa una foto de catálogo del fabricante, solo como referencia dentro del prototipo académico. Esa foto se debe reemplazar por una real del gimnasio antes de publicar la app.

Cuando exista el RF13, el administrador podrá reemplazar todas por fotos reales del gimnasio.

| Máquina | Archivo en el Storage | Original | Autor | Licencia |
|---|---|---|---|---|
| Trotadora | `trotadora.jpg` | [Treadmill-gym.jpg](https://commons.wikimedia.org/wiki/File:Treadmill-gym.jpg) | GhoziSeptiandri | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0) |
| Elíptica | `eliptica.jpg` | [Elliptical machine.jpg](https://commons.wikimedia.org/wiki/File:Elliptical_machine.jpg) | Cpetro45 | [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0) |
| Bicicleta estática | `bicicleta-estatica.jpg` | [Exercise bike - 29792771184 - 2016-10-19.jpg](https://commons.wikimedia.org/wiki/File:Exercise_bike_-_29792771184_-_2016-10-19.jpg) | TChapman9 | [CC BY 2.0](https://creativecommons.org/licenses/by/2.0) |
| Banco plano | `banco-plano.jpg` | [Weight Bench set.jpg](https://commons.wikimedia.org/wiki/File:Weight_Bench_set.jpg) | SAgbley | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0) |
| Rack de sentadilla | `rack-de-sentadilla.jpg` | [Power Rack.JPG](https://commons.wikimedia.org/wiki/File:Power_Rack.JPG) | Wissembourg | [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0) |
| Mancuernas | `mancuernas.jpg` | [Marines' voices echo, prompt new gym hours 150927-M-AI083-067.jpg](https://commons.wikimedia.org/wiki/File:Marines%27_voices_echo,_prompt_new_gym_hours_150927-M-AI083-067.jpg) | Lance Cpl. Jason Jimenez, U.S. Marine Corps | Dominio público |
| Prensa de piernas | `prensa-de-piernas.jpg` | [Leg Press Machine.jpg](https://commons.wikimedia.org/wiki/File:Leg_Press_Machine.jpg) | Paulmcdonald | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0) |
| Jalón al pecho | `jalon-al-pecho.jpg` | [Diverging Lat Pulldown Machine.jpg](https://commons.wikimedia.org/wiki/File:Diverging_Lat_Pulldown_Machine.jpg) | Teddyhtsai | [CC0](https://creativecommons.org/publicdomain/zero/1.0/) |
| Extensión de cuádriceps | `extension-de-cuadriceps.jpg` | [Leg Extension.jpg](https://commons.wikimedia.org/wiki/File:Leg_Extension.jpg) | Aliva Sahoo | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0) |
| Máquina Smith | `maquina-smith.jpg` | [Smith machine.webp](https://commons.wikimedia.org/wiki/File:Smith_machine.webp) | Wikideas1 | [CC0](https://creativecommons.org/publicdomain/zero/1.0/) |
| Banco inclinado | `banco-inclinado.jpg` | [Incline bench for bench pressing.jpg](https://commons.wikimedia.org/wiki/File:Incline_bench_for_bench_pressing.jpg) | Teemeah | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0) |
| Banco Scott | `banco-scott.jpg` | [PreacherBenchBicepsCurl.JPG](https://commons.wikimedia.org/wiki/File:PreacherBenchBicepsCurl.JPG) | GeorgeStepanek | [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0) |
| Máquina de aperturas | `maquina-de-aperturas.jpg` | [Pec deck Fly.jpg](https://commons.wikimedia.org/wiki/File:Pec_deck_Fly.jpg) | Aliva Sahoo | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0) |
| Sentadilla hack | `sentadilla-hack.jpg` | [David Jobson & Ziggy Chima; machine hack squat.jpg](https://commons.wikimedia.org/wiki/File:David_Jobson_%26_Ziggy_Chima;_machine_hack_squat.jpg) | brett jordan | [CC BY 2.0](https://creativecommons.org/licenses/by/2.0) |
| Bicicleta reclinada | `bicicleta-reclinada.jpg` | Foto de catálogo de la bicicleta Etenon VR9 | Etenon (fabricante) | Sin licencia libre; solo referencia |
