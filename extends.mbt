// Explicit `extend` declarations for derived trait impls.
//
// moonc v0.10.18 deprecates the implicit promotion of derived trait methods
// into regular methods (`implicit_impl_as_method`), which breaks
// `moon check --deny-warn`. Following the convention used by
// `moonbitlang/core` (see its per-package `extends.mbt` files), the primary
// method of each builtin trait stays promoted, while the derivatives keep
// working but are deprecated and hidden from the generated interface.

// --- promoted: kept as regular methods ---

///|
pub extend AuditEntry with Eq::{equal}

///|
pub extend DeadLetterEntry with Eq::{equal}

///|
pub extend DeliveryAttempt with Eq::{equal}

///|
pub extend DeliveryOutcome with Eq::{equal}

///|
pub extend DeliveryResult with Eq::{equal}

///|
pub extend DeliveryStatus with Eq::{equal}

///|
pub extend EventBuilder with Eq::{equal}

///|
pub extend Hook with Eq::{equal}

///|
pub extend IdempotencyRecord with Eq::{equal}

///|
pub extend PendingDelivery with Eq::{equal}

///|
pub extend RetryPolicy with Eq::{equal}

///|
pub extend SignatureProvider with Eq::{equal}

///|
pub extend SignedRequest with Eq::{equal}

///|
pub extend WebhookEvent with Eq::{equal}

// --- deprecated: hidden from the generated interface ---

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend AuditEntry with @debug.Debug::{to_repr}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend AuditLog with @debug.Debug::{to_repr}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend DeadLetterEntry with @debug.Debug::{to_repr}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend DeliveryAttempt with @debug.Debug::{to_repr}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend DeliveryOutcome with @debug.Debug::{to_repr}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend DeliveryResult with @debug.Debug::{to_repr}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend DeliveryStatus with @debug.Debug::{to_repr}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend EventBuilder with @debug.Debug::{to_repr}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend Hook with @debug.Debug::{to_repr}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend HookRegistry with @debug.Debug::{to_repr}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend IdempotencyRecord with @debug.Debug::{to_repr}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend IdempotencyStore with @debug.Debug::{to_repr}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend InMemoryDeadLetter with @debug.Debug::{to_repr}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend InMemoryOutbox with @debug.Debug::{to_repr}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend MockTransport with @debug.Debug::{to_repr}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend PendingDelivery with @debug.Debug::{to_repr}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend RetryPolicy with @debug.Debug::{to_repr}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend SignatureProvider with @debug.Debug::{to_repr}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend SignedRequest with @debug.Debug::{to_repr}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend WebhookEvent with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend AuditEntry with Eq::{not_equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend DeadLetterEntry with Eq::{not_equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend DeliveryAttempt with Eq::{not_equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend DeliveryOutcome with Eq::{not_equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend DeliveryResult with Eq::{not_equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend DeliveryStatus with Eq::{not_equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend EventBuilder with Eq::{not_equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend Hook with Eq::{not_equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend IdempotencyRecord with Eq::{not_equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend PendingDelivery with Eq::{not_equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend RetryPolicy with Eq::{not_equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend SignatureProvider with Eq::{not_equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend SignedRequest with Eq::{not_equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend WebhookEvent with Eq::{not_equal}
