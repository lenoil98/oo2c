#include "./Var3b.d"
#include "__oo2c.h"

static OOC_INT16 Var3b__F(OOC_CHAR8 a, OOC_CHAR8 b) {
  register OOC_INT32 i0,i1;

  i0 = a;
  if (i0) goto l5;
  i1 = b;
  if (i1) goto l3;
  i1=0;
  goto l4;
l3:
  i1=1;
l4:
  i0=i1;
  goto l6;
l5:
  i0=2;
l6:
  return i0;
}

void Var3b__Test() {
  register OOC_INT32 i0;

  i0 = Var3b__F(OOC_FALSE, OOC_FALSE);
  Out__Int(i0, 0);
  Out__Ln();
  i0 = Var3b__F(OOC_FALSE, OOC_TRUE);
  Out__Int(i0, 0);
  Out__Ln();
  i0 = Var3b__F(OOC_TRUE, OOC_FALSE);
  Out__Int(i0, 0);
  Out__Ln();
  i0 = Var3b__F(OOC_TRUE, OOC_TRUE);
  Out__Int(i0, 0);
  Out__Ln();
  return;
}

void Var3b_init(void) {
}
