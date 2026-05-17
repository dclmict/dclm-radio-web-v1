
              <?php foreach ($languages as $langSlug => $langData): ?>
              <a href="<?= $langSlug === '' ? '/' : htmlspecialchars($langSlug) ?>" class="hollow button"><?= htmlspecialchars($langData['label']) ?></a>
              <?php endforeach; ?>
