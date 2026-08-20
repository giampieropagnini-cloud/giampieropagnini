# Prove sul catalogo delle telecamere: ogni modello deve essere coerente.

import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from app.registry import TELECAMERE  # noqa: E402


class ProveCatalogo(unittest.TestCase):

    def test_ci_sono_le_tre_telecamere(self):
        self.assertEqual(set(TELECAMERE), {"go3s", "acepro2", "x6"})

    def test_ogni_telecamera_e_coerente(self):
        for spec in TELECAMERE.values():
            with self.subTest(telecamera=spec.id):
                tipi = {m.tipo for m in spec.modalita}
                self.assertIn("foto", tipi)
                self.assertIn("video", tipi)

                id_modalita = [m.id for m in spec.modalita]
                self.assertEqual(len(id_modalita), len(set(id_modalita)),
                                 "modalità con id doppi")
                for m in spec.modalita:
                    self.assertTrue(m.risoluzioni, "modalità senza risoluzioni")
                    if m.tipo == "video":
                        self.assertGreater(m.gb_al_minuto, 0)
                    else:
                        self.assertGreater(m.peso_foto_mb, 0)

                id_imp = [i.id for i in spec.impostazioni]
                self.assertEqual(len(id_imp), len(set(id_imp)),
                                 "impostazioni con id doppi")
                for imp in spec.impostazioni:
                    self.assertIn(imp.predefinita, imp.opzioni,
                                  "valore predefinito fuori dalle opzioni")

    def test_tutte_hanno_autoscatto_e_griglia(self):
        for spec in TELECAMERE.values():
            ids = {i.id for i in spec.impostazioni}
            self.assertIn("timer", ids)
            self.assertIn("griglia", ids)


if __name__ == "__main__":
    unittest.main()
