const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();

// ═══════════════════════════════════════════════════════════
// FAMILY CHAT NOTIFICATION
// ═══════════════════════════════════════════════════════════

exports.onFamilyChatMessageCreated = onDocumentCreated(
  "households/{householdId}/familyChatMessages/{messageId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log("No data associated with the event");
      return;
    }

    const messageData = snapshot.data();
    const senderId = messageData.senderId;
    const senderName = messageData.senderName;
    const text = messageData.text;
    const householdId = event.params.householdId;

    console.log(`New message in household ${householdId} from ${senderId}`);

    try {
      const tokens = await _getOtherMemberTokens(householdId, senderId);
      if (tokens.length === 0) return;

      const payload = {
        notification: {
          title: `💬 ${senderName}`,
          body: text.length > 100 ? text.substring(0, 97) + "..." : text,
        },
        data: {
          type: "chat_message",
          householdId: householdId,
          messageId: event.params.messageId,
        },
        tokens: tokens,
      };

      const response = await admin.messaging().sendEachForMulticast(payload);
      console.log(
        `Chat: ${response.successCount} sent, ${response.failureCount} failed`
      );
      _logFailures(response);
    } catch (error) {
      console.error("Error sending chat notification:", error);
    }
  }
);



// ═══════════════════════════════════════════════════════════
// TASK ASSIGNMENT NOTIFICATION
// ═══════════════════════════════════════════════════════════

exports.onTaskAssigned = onDocumentUpdated(
  "households/{householdId}/householdTasks/{taskId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    // Only fire if assignedTo changed and is now set
    if (before.assignedTo === after.assignedTo || !after.assignedTo) return;

    const householdId = event.params.householdId;
    const assignedTo = after.assignedTo;
    const taskTitle = after.title || "Untitled task";

    console.log(`Task "${taskTitle}" assigned to ${assignedTo} in ${householdId}`);

    try {
      // Get the assigned user's FCM token
      const userDoc = await admin
        .firestore()
        .collection("users")
        .doc(assignedTo)
        .get();

      if (!userDoc.exists || !userDoc.data().fcmToken) {
        console.log("Assigned user has no FCM token");
        return;
      }

      const dueInfo = after.dueDate
        ? ` (Due: ${new Date(after.dueDate).toLocaleDateString()})`
        : "";

      const message = {
        notification: {
          title: "📋 New Task Assigned",
          body: `${taskTitle}${dueInfo}`,
        },
        data: {
          type: "task_assigned",
          householdId: householdId,
          taskId: event.params.taskId,
        },
        token: userDoc.data().fcmToken,
      };

      await admin.messaging().send(message);
      console.log("Task assignment notification sent");
    } catch (error) {
      console.error("Error sending task assignment notification:", error);
    }
  }
);

// ═══════════════════════════════════════════════════════════
// EXPENSE ALERT (₹500+ threshold)
// ═══════════════════════════════════════════════════════════

exports.onExpenseCreated = onDocumentCreated(
  "households/{householdId}/expenses/{expenseId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const expense = snapshot.data();
    const amount = expense.amount || 0;
    const householdId = event.params.householdId;

    // Only notify for expenses ≥ ₹500
    if (amount < 500) {
      console.log(`Expense ₹${amount} below threshold, skipping`);
      return;
    }

    const paidBy = expense.paidBy || "Someone";
    const category = expense.category || "General";
    const title = expense.title || "Untitled";

    console.log(`Expense ₹${amount} logged in ${householdId}`);

    try {
      // Find who created this — we use paidBy field as the sender
      // Notify all OTHER family members
      const tokens = await _getOtherMemberTokens(householdId, paidBy);
      if (tokens.length === 0) return;

      const payload = {
        notification: {
          title: `💸 ₹${amount.toLocaleString()} Expense Logged`,
          body: `${title} (${category})`,
        },
        data: {
          type: "expense_added",
          householdId: householdId,
          expenseId: event.params.expenseId,
        },
        tokens: tokens,
      };

      const response = await admin.messaging().sendEachForMulticast(payload);
      console.log(
        `Expense: ${response.successCount} sent, ${response.failureCount} failed`
      );
      _logFailures(response);
    } catch (error) {
      console.error("Error sending expense notification:", error);
    }
  }
);

// ═══════════════════════════════════════════════════════════
// GROCERY BATCH NOTIFICATION (3+ items at once)
// ═══════════════════════════════════════════════════════════

// Track recent grocery additions per household (in-memory, resets on cold start)
const recentGroceryAdds = {};

exports.onGroceryItemCreated = onDocumentCreated(
  "households/{householdId}/groceryItems/{itemId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const item = snapshot.data();
    const householdId = event.params.householdId;
    const addedBy = item.addedBy || "Someone";
    const now = Date.now();

    // Initialize tracking for this household
    if (!recentGroceryAdds[householdId]) {
      recentGroceryAdds[householdId] = [];
    }

    // Add current item timestamp and clean up old entries (> 30 seconds)
    recentGroceryAdds[householdId] = recentGroceryAdds[householdId]
      .filter((t) => now - t.time < 30000);
    recentGroceryAdds[householdId].push({
      time: now,
      addedBy: addedBy,
      name: item.name,
    });

    // Count items added in the last 30 seconds by the same person
    const recentByUser = recentGroceryAdds[householdId].filter(
      (t) => t.addedBy === addedBy
    );

    // Only notify when exactly 3 items are reached (to avoid repeated notifications)
    if (recentByUser.length === 3) {
      console.log(`Grocery batch: ${addedBy} added 3+ items in ${householdId}`);

      try {
        const tokens = await _getOtherMemberTokens(householdId, addedBy);
        if (tokens.length === 0) return;

        const payload = {
          notification: {
            title: "🛒 Grocery List Updated",
            body: `${addedBy} added ${recentByUser.length} items to the list`,
          },
          data: {
            type: "grocery_batch",
            householdId: householdId,
          },
          tokens: tokens,
        };

        const response = await admin.messaging().sendEachForMulticast(payload);
        console.log(
          `Grocery: ${response.successCount} sent, ${response.failureCount} failed`
        );
        _logFailures(response);
      } catch (error) {
        console.error("Error sending grocery notification:", error);
      }
    }
  }
);

// ═══════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════

/**
 * Get FCM tokens for all household members except the specified user.
 */
async function _getOtherMemberTokens(householdId, excludeUserId) {
  const householdDoc = await admin
    .firestore()
    .collection("households")
    .doc(householdId)
    .get();

  if (!householdDoc.exists) {
    console.log("Household does not exist");
    return [];
  }

  const members = householdDoc.data().members || [];
  const recipientIds = members.filter((id) => id !== excludeUserId);

  if (recipientIds.length === 0) {
    console.log("No other members to notify");
    return [];
  }

  const tokens = [];
  const usersRef = admin.firestore().collection("users");

  await Promise.all(
    recipientIds.map(async (userId) => {
      const userDoc = await usersRef.doc(userId).get();
      if (userDoc.exists && userDoc.data().fcmToken) {
        tokens.push(userDoc.data().fcmToken);
      }
    })
  );

  return tokens;
}

/**
 * Log any FCM send failures for debugging.
 */
function _logFailures(response) {
  if (response.failureCount > 0) {
    response.responses.forEach((resp, idx) => {
      if (!resp.success) {
        console.error(`Failed token at index ${idx}: `, resp.error);
      }
    });
  }
}

const { onDocumentWritten } = require("firebase-functions/v2/firestore");

// ═════════════════════════════════════════════════════
//  NEW BILL NOTIFICATION
// ═════════════════════════════════════════════════════

exports.onNewBillCreated = onDocumentCreated(
  "households/{householdId}/utilityBills/{billId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const bill = snapshot.data();
    const householdId = event.params.householdId;
    const billType = bill.type || "Bill";
    const amount = bill.amount || 0;

    console.log(`New ${billType} bill ₹${amount} in ${householdId}`);

    try {
      const tokens = await _getOtherMemberTokens(householdId, "__none__");
      if (tokens.length === 0) return;

      const dueInfo = bill.dueDate
        ? ` — Due ${new Date(bill.dueDate).toLocaleDateString()}`
        : "";

      const payload = {
        notification: {
          title: `💰 New ${billType} Bill Added`,
          body: `₹${amount.toLocaleString()}${dueInfo}`,
        },
        data: {
          type: "bill_added",
          householdId: householdId,
          billId: event.params.billId,
        },
        tokens: tokens,
      };

      const response = await admin.messaging().sendEachForMulticast(payload);
      console.log(
        `Bill: ${response.successCount} sent, ${response.failureCount} failed`
      );
      _logFailures(response);
    } catch (error) {
      console.error("Error sending bill notification:", error);
    }
  }
);

// ═════════════════════════════════════════════════════
//  OVERDUE BILL SMART ALERT (v2 API)
// ═════════════════════════════════════════════════════

exports.onBillOverdueCheck = onDocumentWritten(
  "households/{householdId}/utilityBills/{billId}",
  async (event) => {
    const householdId = event.params.householdId;
    const afterSnap = event.data.after;
    if (!afterSnap.exists) return; // Bill was deleted

    const data = afterSnap.data();
    const isPaid = data.isPaid || false;
    if (isPaid) return;

    // Parse dueDate — could be a Firestore Timestamp or ISO string
    let dueDate;
    if (data.dueDate && data.dueDate.toDate) {
      dueDate = data.dueDate.toDate();
    } else if (data.dueDate) {
      dueDate = new Date(data.dueDate);
    } else {
      return;
    }

    const now = new Date();
    const diffDays = Math.floor((now - dueDate) / (1000 * 60 * 60 * 24));
    if (diffDays < 1) return;

    const billType = data.type || "Bill";
    const amount = data.amount || 0;

    try {
      const tokens = await _getOtherMemberTokens(householdId, "__none__");
      if (tokens.length === 0) return;

      const response = await admin.messaging().sendEachForMulticast({
        tokens: tokens,
        notification: {
          title: `🚨 Overdue: ${billType} Bill`,
          body: `₹${amount} was due ${diffDays} day${diffDays > 1 ? "s" : ""} ago. Pay it now to avoid penalties.`,
        },
        data: {
          type: "ai_smart_bill",
          householdId: householdId,
        },
      });

      console.log(
        `Overdue bill alert: ${response.successCount} sent, ${response.failureCount} failed`
      );
      _logFailures(response);
    } catch (error) {
      console.error("Error sending overdue bill notification:", error);
    }
  }
);

// ═════════════════════════════════════════════════════
//  MAINTENANCE OVERDUE ALERT
// ═════════════════════════════════════════════════════

exports.onMaintenanceOverdue = onDocumentWritten(
  "households/{householdId}/maintenanceTasks/{taskId}",
  async (event) => {
    const afterSnap = event.data.after;
    if (!afterSnap.exists) return;

    const data = afterSnap.data();
    if (data.isCompleted) return;

    let nextDue;
    if (data.nextDue && data.nextDue.toDate) {
      nextDue = data.nextDue.toDate();
    } else if (data.nextDue) {
      nextDue = new Date(data.nextDue);
    } else {
      return;
    }

    const now = new Date();
    const diffDays = Math.floor((now - nextDue) / (1000 * 60 * 60 * 24));
    if (diffDays < 1) return;

    const householdId = event.params.householdId;
    const taskName = data.name || "Maintenance";

    try {
      const tokens = await _getOtherMemberTokens(householdId, "__none__");
      if (tokens.length === 0) return;

      const response = await admin.messaging().sendEachForMulticast({
        tokens: tokens,
        notification: {
          title: `🔧 Maintenance Overdue: ${taskName}`,
          body: `Service was due ${diffDays} day${diffDays > 1 ? "s" : ""} ago. Schedule it soon!`,
        },
        data: {
          type: "maintenance_overdue",
          householdId: householdId,
        },
      });

      console.log(
        `Maintenance overdue: ${response.successCount} sent, ${response.failureCount} failed`
      );
      _logFailures(response);
    } catch (error) {
      console.error("Error sending maintenance notification:", error);
    }
  }
);
