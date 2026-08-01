/* blast — the composed face's C ABI.
 *
 * The four composed verbs that need both engines over CURRENT bytes
 * (blast_run). Everything this header does not itself declare comes from
 * libirregex via <irregex.h>: status codes, the fault pull, the warm engine and
 * its cancel token, and the row cursor (irregex_rows_*). Link libblast and
 * libirregex.
 *
 * blast_run returns an irregex_rows * walked by the four irregex_rows_*
 * symbols. That is deliberate: gist_run, relate_run, and blast_run all hand
 * back the same cursor, and all three take the same engine. */
#ifndef BLAST_H
#define BLAST_H

#include <irregex.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Verb op codes for blast_run — same numeric values as the ecosystem-wide
 * verb table in irregex/contract/analytic.toml. A host that already stored the numbers
 * keeps them; only the library that answers them has moved. */
#define BLAST_OP_CONTEXT 13u
#define BLAST_OP_FAMILY 14u
#define BLAST_OP_PROVENANCE 15u
#define BLAST_OP_BLAST 16u

/* Analytic params flags shared with the other producers. The presence bits
 * exist because 0.0 is a MEANINGFUL threshold, so "unset" cannot be spelled
 * as zero the way an integer budget can. */
#define BLAST_AN_MAX_DISTANCE (1u << 0) /* params.max_distance is present */
#define BLAST_AN_MIN_ECHO (1u << 1)     /* params.min_echo is present     */
#define BLAST_AN_NO_INDEX (1u << 2)     /* force the live build           */
#define BLAST_AN_FIXED (1u << 3)        /* -F for the verb's patterns     */
#define BLAST_AN_IGNORE_CASE (1u << 4)  /* -i for the verb's patterns     */
#define BLAST_AN_MATCH_ALL (1u << 5)    /* compose: --match all, else any */

/* context · family · provenance · blast — an exact PatternSet narrows a
 * candidate set, then the compression kernel reasons INSIDE it. Initialize
 * struct_size to sizeof(blast_compose_params). `top` 0 = unbounded. */
typedef struct {
  uint32_t struct_size;
  uint32_t flags;
  const uint8_t *text;
  size_t text_len;
  const irregex_text *patterns;
  size_t npatterns;
  double max_distance;
  double min_echo;
  uint32_t budget;
  uint32_t top;
} blast_compose_params;

/* Run one blast verb and materialize a row cursor; writes it to *out.
 * `op` is a BLAST_OP_* code and `params` MUST be the compose family — a
 * mismatched or wrongly-sized struct is IRREGEX_INVALID. `cancel` is optional
 * (NULL = none) and is the same token the exact plane uses.
 *
 * Returns IRREGEX_OK, or a negative fail-closed status. IRREGEX_STALE means
 * this tier declines and the caller should answer through the subprocess
 * fallback — it is NOT a failure.
 *
 * The cursor is an irregex_rows *: walk it with irregex_rows_next /
 * _next_batch / _stats and free it with irregex_rows_close from libirregex. */
int32_t blast_run(irregex_engine *engine, uint32_t op, const void *params,
                  irregex_cancel *cancel, irregex_rows **out);

#ifdef __cplusplus
}
#endif

#endif /* BLAST_H */
